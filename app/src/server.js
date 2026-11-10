// kk-payments — reference service for the KijaniKiosk capstone (Track A).
// Merge this with your Week 8/9 kk-payments source; keep YOUR business logic,
// adopt the operational endpoints (health, ready, metrics, structured logs).
//
// All configuration comes from the environment (ConfigMap + Secret), never from code.
'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const cfg = {
  port: Number(process.env.APP_PORT || process.env.PORT || 3001),
  version: process.env.APP_VERSION || 'unknown',
  env: process.env.APP_ENV || 'unknown',              // "staging" | "production"
  dbHost: process.env.DB_HOST || 'unset',
  bucket: process.env.RECEIPTS_BUCKET || '',
  s3Endpoint: process.env.S3_ENDPOINT || '',           // e.g. http://host.minikube.internal:9000
  faultMode: process.env.FAULT_MODE || 'none',         // none | error | crash  (demo only)
};

const s3 = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  endpoint: cfg.s3Endpoint || undefined,
  forcePathStyle: true,                                // required for MinIO / local S3
});

// ---- structured logging: one JSON object per line on stdout ----
function log(level, msg, extra = {}) {
  process.stdout.write(JSON.stringify({
    ts: new Date().toISOString(), level, service: 'kk-payments',
    env: cfg.env, version: cfg.version, msg, ...extra,
  }) + '\n');
}

// ---- minimal Prometheus metrics (no extra dependency) ----
const counters = new Map();   // key: `${route}|${status}`
const latency = { sum: 0, count: 0 };
function record(route, status, ms) {
  const k = `${route}|${status}`;
  counters.set(k, (counters.get(k) || 0) + 1);
  latency.sum += ms / 1000; latency.count += 1;
}
function metricsText() {
  let out = '# HELP kk_http_requests_total HTTP requests by route and status\n# TYPE kk_http_requests_total counter\n';
  for (const [k, v] of counters) {
    const [route, status] = k.split('|');
    out += `kk_http_requests_total{route="${route}",status="${status}"} ${v}\n`;
  }
  out += '# TYPE kk_http_request_duration_seconds summary\n';
  out += `kk_http_request_duration_seconds_sum ${latency.sum}\nkk_http_request_duration_seconds_count ${latency.count}\n`;
  return out;
}

function send(res, status, body, type = 'application/json') {
  res.writeHead(status, { 'Content-Type': type });
  res.end(type === 'application/json' ? JSON.stringify(body) : body);
}

let ready = false;
let shuttingDown = false;

async function createPayment(req, res) {
  let raw = '';
  for await (const chunk of req) raw += chunk;
  let body;
  try { body = JSON.parse(raw || '{}'); } catch { return send(res, 400, { error: 'invalid JSON' }); }
  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount <= 0) return send(res, 400, { error: 'amount must be a positive number' });

  if (cfg.faultMode === 'error') {             // deliberate fault for the demo
    log('error', 'payment failed (FAULT_MODE=error)', { amount });
    return send(res, 500, { error: 'simulated failure' });
  }

  // orderId links this payment to the Week 10 receipt chain. Generate one if the caller sent none.
  const orderId = String(body.orderId || `ORD-${crypto.randomUUID().slice(0, 8)}`);
  if (!/^[A-Za-z0-9-]{1,64}$/.test(orderId)) return send(res, 400, { error: 'orderId may only contain letters, digits and dashes' });

  const receipt = {
    receiptId: crypto.randomUUID(), orderId, amount, currency: body.currency || 'KES', source: 'kk-payments',
    createdAt: new Date().toISOString(), env: cfg.env, version: cfg.version,
    smokeTest: body.smoke_test === true,     // lets the chain tell test payments from real ones
  };
  // Same key format as the Week 10 chain expects: receipt-<orderId>.json at the bucket root.
  const key = `receipt-${orderId}.json`;
  await s3.send(new PutObjectCommand({
    Bucket: cfg.bucket, Key: key, Body: JSON.stringify(receipt), ContentType: 'application/json',
  }));
  log('info', 'receipt written', { orderId, receiptId: receipt.receiptId, bucket: cfg.bucket, key, amount });
  return send(res, 201, { ...receipt, receipt_key: key, bucket: cfg.bucket });
}

const server = http.createServer(async (req, res) => {
  const start = Date.now();
  const route = req.url.split('?')[0];
  res.on('finish', () => {
    record(route, res.statusCode, Date.now() - start);
    if (route !== '/metrics' && route !== '/health' && route !== '/ready') {
      log('info', 'request', { method: req.method, route, status: res.statusCode, ms: Date.now() - start });
    }
  });
  try {
    if (req.method === 'GET' && route === '/health') {
      // Liveness: is the process able to answer at all?
      return send(res, 200, { status: 'ok', version: cfg.version, env: cfg.env, db_host: cfg.dbHost });
    }
    if (req.method === 'GET' && route === '/ready') {
      // Readiness: should this pod receive traffic right now?
      const ok = ready && !shuttingDown && Boolean(cfg.bucket);
      return send(res, ok ? 200 : 503, { ready: ok });
    }
    if (req.method === 'GET' && route === '/metrics') return send(res, 200, metricsText(), 'text/plain; version=0.0.4');
    if (req.method === 'POST' && route === '/payments') return await createPayment(req, res);
    return send(res, 404, { error: 'not found' });
  } catch (err) {
    log('error', 'unhandled error', { route, error: err.message });
    return send(res, 500, { error: 'internal error' });
  }
});

if (cfg.faultMode === 'crash') {
  // Deliberate fault: process dies shortly after start -> CrashLoopBackOff -> restart alert.
  log('error', 'FAULT_MODE=crash: exiting in 5s');
  setTimeout(() => process.exit(1), 5000);
}

server.listen(cfg.port, () => {
  ready = true;
  log('info', 'kk-payments started', { port: cfg.port, db_host: cfg.dbHost, bucket: cfg.bucket, fault_mode: cfg.faultMode });
});

// Graceful shutdown: stop taking traffic, finish in-flight requests, then exit.
process.on('SIGTERM', () => {
  shuttingDown = true;
  log('info', 'SIGTERM received, draining');
  server.close(() => { log('info', 'shutdown complete'); process.exit(0); });
  setTimeout(() => process.exit(0), 10000).unref();
});
