#!/usr/bin/env node
// Manual service-role operation. Never bundle this file or its key into Flutter.
const [mode = '--dry-run', requestId] = process.argv.slice(2);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!['--dry-run', '--execute', '--reconcile'].includes(mode) ||
    !uuid.test(requestId ?? '')) {
  console.error('Usage: node process_account_deletion.mjs [--dry-run|--execute] REQUEST_UUID');
  console.error('   or: node process_account_deletion.mjs --reconcile REQUEST_UUID');
  process.exit(2);
}
let base;
try {
  const endpoint = new URL(process.env.SUPABASE_URL ?? '');
  if (endpoint.protocol === 'https:' && endpoint.hostname &&
      !endpoint.username && !endpoint.password &&
      (endpoint.pathname === '/' || endpoint.pathname === '') &&
      !endpoint.search && !endpoint.hash) {
    base = endpoint.origin;
  }
} catch (_) {}
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!base || !key) {
  console.error('Set HTTPS SUPABASE_URL and server-only SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(2);
}
const headers = { apikey: key, Authorization: `Bearer ${key}` };
async function api(path, options = {}, allowed = [200]) {
  const response = await fetch(`${base}${path}`, {
    ...options,
    headers: { ...headers, ...(options.headers ?? {}) },
    signal: AbortSignal.timeout(30000),
    redirect: 'error',
  });
  if (!allowed.includes(response.status)) {
    throw new Error(`${path.split('?')[0]} returned HTTP ${response.status}`);
  }
  return response;
}
async function complete() {
  const response = await api('/rest/v1/rpc/finalize_account_deletion', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ target_request: requestId }),
  });
  if (await response.json() !== true) throw new Error('Deletion completion was not confirmed.');
}

try {
  if (mode === '--reconcile') {
    // A durable job proves that this exact request was prepared by the server.
    const response = await api(`/rest/v1/account_deletion_operations?request_id=eq.${requestId}&select=user_id,status`);
    const jobs = await response.json();
    if (jobs.length !== 1) throw new Error('No prepared operation for this request.');
    if (jobs[0].status === 'deleted') {
      console.log(JSON.stringify({ request_id: requestId, status: 'deleted' }));
      process.exit(0);
    }
    const check = await api(`/auth/v1/admin/users/${jobs[0].user_id}`, {}, [200, 404]);
    if (check.status !== 404) throw new Error('Auth user still exists; reconciliation refused.');
    await complete();
    console.log(JSON.stringify({ request_id: requestId, status: 'deleted' }));
    process.exit(0);
  }
  const previewResponse = await api('/rest/v1/rpc/inspect_account_deletion', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ target_request: requestId }),
  });
  const row = await previewResponse.json();
  if (mode === '--dry-run') {
    console.log(JSON.stringify({ request_id: requestId, status: row.status,
      ready: row.ready, blockers: row.blockers }, null, 2));
    process.exit(0);
  }
  if (row.status !== 'pending' || !row.ready) throw new Error('Request is not pending or has data-retention blockers.');
  const prepared = await api('/rest/v1/rpc/prepare_account_deletion', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ target_request: requestId }),
  });
  const result = await prepared.json();
  if (!result.ready || result.user_id !== row.user_id) {
    throw new Error(`Preflight changed: ${JSON.stringify(result.blockers ?? {})}`);
  }
  // The request ID is sufficient for recovery; avoid logging the user ID.
  console.log(JSON.stringify({ request_id: requestId, status: 'processing' }));
  await api(`/auth/v1/admin/users/${row.user_id}`, { method: 'DELETE' }, [200, 204]);
  await complete();
  console.log(JSON.stringify({ request_id: requestId, status: 'deleted' }));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
