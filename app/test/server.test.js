// Runs with `npm test` — no test framework dependency.
'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { spawn } = require('node:child_process');
const path = require('node:path');

const PORT = 3999;
let proc;

before(async () => {
  proc = spawn('node', [path.join(__dirname, '..', 'src', 'server.js')], {
    env: { ...process.env, PORT: String(PORT), APP_VERSION: 'test', APP_ENV: 'test', DB_HOST: 'db.test', RECEIPTS_BUCKET: 'test-bucket' },
    stdio: 'ignore',
  });
  for (let i = 0; i < 30; i++) {
    try { await fetch(`http://127.0.0.1:${PORT}/health`); return; } catch { await new Promise(r => setTimeout(r, 100)); }
  }
  throw new Error('server did not start');
});
after(() => proc.kill('SIGTERM'));

test('/health reports version, env and db_host from config', async () => {
  const body = await (await fetch(`http://127.0.0.1:${PORT}/health`)).json();
  assert.deepStrictEqual(body, { status: 'ok', version: 'test', env: 'test', db_host: 'db.test' });
});

test('/ready is 200 when started with a bucket configured', async () => {
  assert.strictEqual((await fetch(`http://127.0.0.1:${PORT}/ready`)).status, 200);
});

test('POST /payments rejects a non-positive amount', async () => {
  const r = await fetch(`http://127.0.0.1:${PORT}/payments`, { method: 'POST', body: JSON.stringify({ amount: -5 }) });
  assert.strictEqual(r.status, 400);
});

test('/metrics exposes the request counter', async () => {
  const text = await (await fetch(`http://127.0.0.1:${PORT}/metrics`)).text();
  assert.match(text, /kk_http_requests_total/);
});
