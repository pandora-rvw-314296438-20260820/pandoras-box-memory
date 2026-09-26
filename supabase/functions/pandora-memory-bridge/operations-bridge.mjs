
// Invoked only AFTER the native bridge verifies the actual Vercel workload JWT.
// This module never accepts caller-supplied principal/user/environment credentials.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const PRINCIPAL = 'pandora-mcpmaster-production';
const ORIGIN = 'https://ivmvufhcsezyhczzondn.supabase.co';
const encode = new TextEncoder();
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const fail = code => { throw new Error(code); };
const requireThat = (condition, code) => { if (!condition) fail(code); };
const deny = (code, status = 400, outcomeUnknown = false) => ({status, body:{ok:false,error:code,outcomeUnknown,canonicalMemoryWritten:false}});
export async function readBridgeBody(request, {maxBytes = 65536, timeoutMs = 5000} = {}) {
  requireThat(Number.isSafeInteger(maxBytes) && maxBytes > 0 && maxBytes <= 65536
    && Number.isSafeInteger(timeoutMs) && timeoutMs > 0 && timeoutMs <= 5000, 'OPS_MEMORY_READ_LIMIT_INVALID');
  const length = request.headers.get('content-length');
  requireThat(length === null || (/^[0-9]+$/.test(length) && Number(length) <= maxBytes), 'OPS_MEMORY_BODY_LIMIT');
  requireThat(!request.signal?.aborted && request.body?.getReader, 'OPS_MEMORY_BODY_INVALID');
  const reader = request.body.getReader();
  let timer, abort;
  const cancel = () => { Promise.resolve(reader.cancel()).catch(() => {}); };
  const stopped = new Promise((_, reject) => {
    abort = () => { cancel(); reject(new Error('OPS_MEMORY_READ_CANCELLED')); };
    request.signal?.addEventListener('abort', abort, {once:true});
    timer = setTimeout(() => { cancel(); reject(new Error('OPS_MEMORY_READ_TIMEOUT')); }, timeoutMs);
  });
  try {
    const value = await Promise.race([(async () => {
      const decoder = new TextDecoder('utf-8', {fatal:true}); let text = '', size = 0;
      while (true) {
        const chunk = await reader.read(); if (chunk.done) break;
        size += chunk.value.byteLength;
        if (size > maxBytes) { cancel(); fail('OPS_MEMORY_BODY_LIMIT'); }
        text += decoder.decode(chunk.value, {stream:true});
      }
      text += decoder.decode(); const body = JSON.parse(text);
      requireThat(record(body), 'OPS_MEMORY_BODY_INVALID'); return body;
    })(), stopped]);
    return value;
  } finally {
    clearTimeout(timer); request.signal?.removeEventListener('abort', abort);
    try { reader.releaseLock(); } catch { /* cancelled pending reader owns its cleanup */ }
  }
}
/** @param {any} body
 * @param {any} principal
 * @param {any} client
 * @param {{ signal?: AbortSignal, timeoutMs?: number }} [options]
 */
export async function handleOperationsMemory(body, principal, client, options = {}) {
  const {signal, timeoutMs = 12000} = options;
  let submitted = false;
  const mutation = body?.operation === 'propose_outcome';
  try {
    requireThat(record(body) && Object.keys(body).length === 6
      && Object.keys(body).every(key => ['action','operation','requestId','projectId','namespace','payload'].includes(key))
      && body.action === 'operations' && UUID.test(body.requestId) && UUID.test(body.projectId)
      && body.namespace === 'real_life' && record(body.payload)
      && ['context','performance','propose_outcome','readback'].includes(body.operation), 'OPS_MEMORY_REQUEST_INVALID');
    requireThat(encode.encode(JSON.stringify(body)).byteLength <= 40000, 'OPS_MEMORY_PAYLOAD_LIMIT');
    requireThat(principal?.is_active === true && principal.project_name === 'mcpmaster'
      && principal.environment === 'production' && UUID.test(principal.memory_user_id)
      && Array.isArray(principal.allowed_namespaces) && principal.allowed_namespaces.includes('real_life')
      && Array.isArray(principal.scopes)
      && principal.scopes.includes(['context','performance'].includes(body.operation) ? 'memory:read' : 'memory:write'), 'OPS_MEMORY_PRINCIPAL_DENIED');
    // No arbitrary URL, function name, SQL, principal key or service credential is forwarded.
    requireThat(client?.supabaseUrl === ORIGIN && typeof client.rpc === 'function', 'OPS_MEMORY_RUNTIME_DENIED');
    requireThat(Number.isSafeInteger(timeoutMs) && timeoutMs > 0 && timeoutMs <= 12000, 'OPS_MEMORY_RUNTIME_DENIED');
    if (signal?.aborted) return deny('OPS_MEMORY_CANCELLED', 409);
    const args = {p_memory_user_id:principal.memory_user_id,p_namespace:'real_life',
      p_project_id:body.projectId,p_principal_key:PRINCIPAL,p_environment:principal.environment};
    const name = body.operation === 'performance' ? 'memory_operations_performance_v1' : 'memory_operations_bridge_v1';
    if (body.operation === 'performance') args.p_request = body.payload;
    else { args.p_operation = body.operation; args.p_payload = body.payload; }
    const controller = new AbortController(); let timer, abort;
    const stopped = new Promise((_, reject) => {
      abort = () => { controller.abort(); reject(new Error('OPS_MEMORY_CANCELLED')); };
      signal?.addEventListener('abort', abort, {once:true});
      timer = setTimeout(() => { controller.abort(); reject(new Error('OPS_MEMORY_TIMEOUT')); }, timeoutMs);
    });
    let result;
    try {
      submitted = true;
      let pending = client.rpc(name, args);
      if (typeof pending?.abortSignal === 'function') pending = pending.abortSignal(controller.signal);
      result = await Promise.race([Promise.resolve(pending), stopped]);
    } finally { clearTimeout(timer); signal?.removeEventListener('abort', abort); }
    if (result?.error) {
      const native = ['P0001','42501','22023','22P02','23505','23514','23503'].includes(result.error.code);
      const code = /^OPS_MEMORY_[A-Z0-9_]{1,100}$/.test(result.error.message || '')
        ? result.error.message : 'OPS_MEMORY_PROVIDER_REJECTED';
      return deny(code, result.error.code === '42501' ? 403 : (native ? 400 : 502), mutation && !native);
    }
    requireThat(record(result?.data) && encode.encode(JSON.stringify(result.data)).byteLength <= 40000, 'OPS_MEMORY_RESPONSE_INVALID');
    return {status:200,body:{ok:true,requestId:body.requestId,operation:body.operation,
      projectId:body.projectId,namespace:body.namespace,memoryProjectRef:'ivmvufhcsezyhczzondn',data:result.data}};
  } catch (error) {
    const known = /^OPS_MEMORY_[A-Z0-9_]{1,100}$/.test(error?.message || '');
    const code = known ? error.message : 'OPS_MEMORY_TRANSPORT_UNAVAILABLE';
    const status = code === 'OPS_MEMORY_PRINCIPAL_DENIED' ? 403 : submitted ? 503 : 400;
    return deny(code, status, mutation && submitted);
  }
}
