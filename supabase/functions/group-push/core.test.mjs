import test from "node:test";
import assert from "node:assert/strict";
import {
  authorized,
  classifyFcm,
  createRpc,
  fcmPayload,
  googleAccessToken,
  processPushBatch,
} from "./core.mjs";

const delivery = {
  token: "fixture-token",
  kind: "message",
  group_id: "10000000-0000-0000-0000-000000000001",
  event_id: "1",
  user_id: "test-user",
  attempts: 1,
  body: "PRIVATE",
  latitude: 21.4,
};
test("lock-screen payload has no message, location, identity or source ID", () => {
  const payload = fcmPayload(delivery);
  assert.deepEqual(Object.keys(payload.message.data).sort(), [
    "event_id",
    "group_id",
    "kind",
  ]);
  assert.equal(JSON.stringify(payload).includes("PRIVATE"), false);
  assert.equal(JSON.stringify(payload).includes("latitude"), false);
  assert.equal(payload.message.apns.headers["apns-expiration"], "0");
});
test("provider acceptance is distinct from device delivery", () => {
  assert.equal(
    classifyFcm(200, { name: "projects/test/messages/1" }, null, 1).outcome,
    "provider_accepted",
  );
  assert.notEqual(classifyFcm(200, {}, null, 1).outcome, "provider_accepted");
});
test("only explicit unregistered token is revoked", () => {
  const body = (code) => ({
    error: {
      details: [{
        "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
        errorCode: code,
      }],
    },
  });
  assert.equal(
    classifyFcm(404, body("UNREGISTERED"), null, 1).outcome,
    "invalid_token",
  );
  for (
    const code of [
      "INVALID_ARGUMENT",
      "SENDER_ID_MISMATCH",
      "THIRD_PARTY_AUTH_ERROR",
    ]
  ) {
    assert.equal(
      classifyFcm(400, body(code), null, 1).outcome,
      "permanent_failure",
    );
  }
});
test("transient errors have bounded backoff and respect Retry-After", () => {
  for (const status of [0, 429, 500, 503]) {
    const result = classifyFcm(status, null, "1200", 3, 0, () => 0);
    assert.equal(result.outcome, "retry");
    assert.equal(result.retry_seconds, 1200);
  }
  assert.equal(classifyFcm(429, null, "999999", 5).retry_seconds, 86400);
  assert.equal(
    classifyFcm(503, null, "invalid", 3, 0, () => 0).retry_seconds,
    240,
  );
  assert.equal(
    classifyFcm(503, null, "Thu, 01 Jan 1970 00:10:00 GMT", 1, 0, () => 0)
      .retry_seconds,
    600,
  );
});
test("authorization fails closed for missing/short/user secrets", async () => {
  const secret = "x".repeat(32);
  assert.equal(
    await authorized(new Request("https://example.test"), secret),
    false,
  );
  assert.equal(
    await authorized(
      new Request("https://example.test", {
        headers: { authorization: `Bearer ${secret}` },
      }),
      secret,
    ),
    true,
  );
  assert.equal(
    await authorized(
      new Request("https://example.test", {
        headers: { authorization: "Bearer user-jwt" },
      }),
      secret,
    ),
    false,
  );
  assert.equal(
    await authorized(new Request("https://example.test"), ""),
    false,
  );
});

function harness(rows = [delivery]) {
  const calls = [];
  const sends = [];
  return {
    calls,
    sends,
    mode: "test",
    allowedUsers: new Set(["test-user"]),
    rpc: async (name, args) => {
      calls.push([name, args]);
      if (name === "claim_push_deliveries") {
        return [{
          id: 1,
          lease_id: "lease",
        }];
      }
      if (name === "prepare_push_delivery") return rows;
      return true;
    },
    send: async (d) => {
      sends.push(d);
      return classifyFcm(200, { name: "accepted" }, null, 1);
    },
  };
}
test("disabled job and unconfigured test allowlist never lease or send", async () => {
  for (const config of [{ mode: "disabled" }, { allowedUsers: new Set() }]) {
    const h = harness();
    await processPushBatch({ ...h, ...config });
    assert.equal(h.calls.length, 0);
    assert.equal(h.sends.length, 0);
  }
});
test("revocation at preparation causes no provider send", async () => {
  const h = harness([]);
  const result = await processPushBatch(h);
  assert.equal(h.sends.length, 0);
  assert.equal(result.skipped, 1);
  assert.equal(h.calls.length, 2);
});
test("test mode excludes real users", async () => {
  const h = harness([{ ...delivery, user_id: "real-user" }]);
  await processPushBatch(h);
  assert.equal(h.sends.length, 0);
  assert.equal(h.calls[2][1].safe_code, "TEST_RECIPIENT_EXCLUDED");
});
test("successful send acknowledges matching lease and reports provider acceptance", async () => {
  const h = harness();
  const result = await processPushBatch(h);
  assert.equal(result.provider_accepted, 1);
  assert.equal(h.calls[2][1].worker_lease, "lease");
  assert.equal(h.calls[2][1].outcome, "provider_accepted");
});
test("network errors are retried without persisting sensitive exceptions", async () => {
  const h = harness();
  h.send = async () => {
    throw new Error("SECRET_TOKEN");
  };
  await processPushBatch(h);
  assert.equal(h.calls[2][1].outcome, "retry");
  assert.equal(JSON.stringify(h.calls).includes("SECRET_TOKEN"), false);
});
test("RPC error never returns provider/database response body", async () => {
  const rpc = createRpc(
    "https://example.test",
    "secret",
    async () => new Response("private database body", { status: 500 }),
  );
  await assert.rejects(rpc("claim_push_deliveries", {}), {
    message: "database job failed",
  });
  assert.throws(() => createRpc("http://example.test", "secret"), /insecure/);
});
test("OAuth uses scoped signed JWT and trusted fixed endpoint", async () => {
  const keys = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const key = await crypto.subtle.exportKey("pkcs8", keys.privateKey);
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    Buffer.from(key).toString("base64")
  }\n-----END PRIVATE KEY-----`;
  const token = await googleAccessToken({
    project_id: "test-project",
    client_email: "test@example.test",
    private_key: pem,
  }, async (url, options) => {
    assert.equal(url, "https://oauth2.googleapis.com/token");
    const jwt = options.body.get("assertion");
    const parts = jwt.split(".");
    const claims = JSON.parse(Buffer.from(parts[1], "base64url"));
    assert.equal(
      claims.scope,
      "https://www.googleapis.com/auth/firebase.messaging",
    );
    assert.equal(claims.exp - claims.iat, 3600);
    assert.equal(
      await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        keys.publicKey,
        Buffer.from(parts[2], "base64url"),
        new TextEncoder().encode(parts.slice(0, 2).join(".")),
      ),
      true,
    );
    return Response.json({ access_token: "fixture-access" });
  });
  assert.equal(token, "fixture-access");
});
