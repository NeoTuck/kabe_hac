import {
  authorized,
  classifyFcm,
  createRpc,
  fcmPayload,
  googleAccessToken,
  processPushBatch,
} from "./core.mjs";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  if (!await authorized(request, Deno.env.get("SERVER_JOB_SECRET"))) {
    return new Response(null, { status: 401 });
  }
  try {
    const mode = Deno.env.get("PUSH_SEND_MODE") ?? "disabled";
    if (!["test", "production"].includes(mode)) {
      return Response.json({ disabled: true });
    }
    const allowedUsers = new Set(
      (Deno.env.get("PUSH_TEST_USER_IDS") ?? "").split(",").filter(Boolean),
    );
    const allowedTokens = new Set(
      (Deno.env.get("PUSH_TEST_TOKEN_IDS") ?? "").split(",").filter(Boolean),
    );
    if (mode === "test" && (!allowedUsers.size || !allowedTokens.size)) {
      return Response.json({ disabled: true });
    }
    const rpc = createRpc(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const account = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!);
    // Authenticate before leasing work; credential failures do not burn delivery attempts.
    const access = await googleAccessToken(account);
    const result = await processPushBatch({
      rpc,
      mode,
      allowedUsers,
      allowedTokens,
      send: async (d: Record<string, string | number>) => {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
          {
            method: "POST",
            signal: AbortSignal.timeout(8000),
            headers: {
              authorization: `Bearer ${access}`,
              "content-type": "application/json",
            },
            body: JSON.stringify(fcmPayload(d)),
          },
        );
        const body = await response.json().catch(() => null);
        return classifyFcm(
          response.status,
          body,
          response.headers.get("retry-after"),
          d.attempts,
        );
      },
    });
    return Response.json(result);
  } catch {
    // No provider body, token, account, JWT, recipient or database error in logs/response.
    return Response.json({ error: "SERVER_JOB_FAILED" }, { status: 503 });
  }
});
