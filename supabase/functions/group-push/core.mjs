// Dependency-free module shared by Supabase Edge Runtime and Node regression tests.
export function classifyFcm(
  status,
  body,
  retryAfter,
  attempt,
  now = Date.now(),
  random = Math.random,
) {
  const detail = body?.error?.details?.find((d) =>
    d["@type"] === "type.googleapis.com/google.firebase.fcm.v1.FcmError"
  );
  const code = detail?.errorCode;
  if (status >= 200 && status < 300 && typeof body?.name === "string") {
    return {
      outcome: "provider_accepted",
      safe_code: "FCM_ACCEPTED",
      retry_seconds: 60,
    };
  }
  // INVALID_ARGUMENT can be a payload/configuration error. Never revoke a token for it.
  if (code === "UNREGISTERED") {
    return {
      outcome: "invalid_token",
      safe_code: "UNREGISTERED",
      retry_seconds: 60,
    };
  }
  if (status === 429 || status >= 500 || status === 0) {
    const numeric = Number(retryAfter);
    const retryMs = retryAfter && Number.isFinite(numeric)
      ? numeric * 1000
      : Date.parse(retryAfter) - now;
    const backoff = 60 * 2 ** Math.min(Math.max(attempt - 1, 0), 4);
    return {
      outcome: "retry",
      safe_code: status === 0 ? "NETWORK" : `HTTP_${status}`,
      retry_seconds: Math.min(
        86400,
        Math.ceil(
          Math.max(
            60,
            Number.isFinite(retryMs) ? retryMs / 1000 : 0,
            backoff + random() * backoff * 0.25,
          ),
        ),
      ),
    };
  }
  return {
    outcome: "permanent_failure",
    safe_code: `HTTP_${status}`,
    retry_seconds: 60,
  };
}

export function fcmPayload(delivery) {
  if (
    !["message", "announcement", "program"].includes(delivery.kind) ||
    !/^[0-9a-f-]{36}$/i.test(delivery.group_id) ||
    !/^\d+$/.test(delivery.event_id)
  ) {
    throw new Error("invalid delivery");
  }
  return {
    message: {
      token: delivery.token,
      notification: {
        title: "Hac/Umre rehberi",
        body: "Kafilede yeni bir güncelleme var.",
      },
      data: {
        kind: delivery.kind,
        group_id: delivery.group_id,
        event_id: delivery.event_id,
      },
      android: { ttl: "60s", collapse_key: delivery.event_id },
      apns: {
        headers: {
          "apns-collapse-id": delivery.event_id,
          "apns-expiration": "0",
        },
      },
    },
  };
}

export async function processPushBatch(
  { rpc, send, allowedUsers, mode, batchSize = 5 },
) {
  if (
    !["test", "production"].includes(mode) ||
    (mode === "test" && !allowedUsers?.size)
  ) {
    return { claimed: 0, provider_accepted: 0, skipped: 0, disabled: true };
  }
  const claims = await rpc("claim_push_deliveries", { batch_size: batchSize });
  const result = {
    claimed: claims.length,
    provider_accepted: 0,
    skipped: 0,
    disabled: false,
  };
  for (const claim of claims) {
    const rows = await rpc("prepare_push_delivery", {
      delivery_id: claim.id,
      worker_lease: claim.lease_id,
    });
    const d = rows[0];
    if (!d) {
      result.skipped++;
      continue;
    }
    let outcome;
    if (mode === "test" && !allowedUsers.has(d.user_id)) {
      outcome = {
        outcome: "permanent_failure",
        safe_code: "TEST_RECIPIENT_EXCLUDED",
        retry_seconds: 60,
      };
    } else {
      try {
        outcome = await send(d);
      } catch {
        outcome = classifyFcm(0, null, null, d.attempts);
      }
    }
    // A stale/expired lease cannot acknowledge another worker's send.
    const saved = await rpc("finish_push_delivery", {
      delivery_id: claim.id,
      worker_lease: claim.lease_id,
      ...outcome,
    });
    if (saved && outcome.outcome === "provider_accepted") {
      result.provider_accepted++;
    }
  }
  return result;
}

function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll(
    "/",
    "_",
  ).replace(/=+$/, "");
}
const encode = (value) =>
  base64url(new TextEncoder().encode(JSON.stringify(value)));

export async function googleAccessToken(
  account,
  fetcher = fetch,
  now = Date.now(),
) {
  if (
    !/^[a-z][a-z0-9-]{4,62}$/.test(account.project_id) ||
    !account.client_email || !account.private_key
  ) {
    throw new Error("invalid server credentials");
  }
  const seconds = Math.floor(now / 1000);
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${
    encode({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: seconds,
      exp: seconds + 3600,
    })
  }`;
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(
    /\s/g,
    "",
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const response = await fetcher("https://oauth2.googleapis.com/token", {
    method: "POST",
    signal: AbortSignal.timeout(8000),
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(new Uint8Array(signature))}`,
    }),
  });
  if (!response.ok) throw new Error("server authentication failed");
  const body = await response.json();
  if (typeof body.access_token !== "string") {
    throw new Error("server authentication failed");
  }
  return body.access_token;
}

export function createRpc(url, serviceKey, fetcher = fetch) {
  if (
    new URL(url).protocol !== "https:" &&
    !["localhost", "127.0.0.1"].includes(new URL(url).hostname)
  ) {
    throw new Error("insecure backend");
  }
  return async (name, args) => {
    const response = await fetcher(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      signal: AbortSignal.timeout(8000),
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(args),
    });
    if (!response.ok) throw new Error("database job failed");
    return response.json();
  };
}

export async function authorized(request, secret) {
  if (!secret || secret.length < 32) return false;
  const hash = async (value) =>
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    );
  const [a, b] = await Promise.all([
    hash(request.headers.get("authorization") || ""),
    hash(`Bearer ${secret}`),
  ]);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}
