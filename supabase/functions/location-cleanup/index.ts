import { authorized, createRpc } from "../group-push/core.mjs";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  if (!await authorized(request, Deno.env.get("SERVER_JOB_SECRET"))) {
    return new Response(null, { status: 401 });
  }
  try {
    const rpc = createRpc(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const removed = await rpc("cleanup_expired_locations", { batch_size: 100 });
    return Response.json({ removed });
  } catch {
    return Response.json({ error: "SERVER_JOB_FAILED" }, { status: 503 });
  }
});
