const test = require('node:test');
const assert = require('node:assert/strict');
const { app, server, getOrCreateSession } = require('../src/server');

test('GET /health returns status ok', async () => {
  const res = await makeRequest('/health', 'GET');
  assert.equal(res.status, 'ok');
});

test('GET /api/token returns authenticated token and identity', async () => {
  const res = await makeRequest('/api/token?identity=android_tester', 'GET');
  assert.equal(res.identity, 'android_tester');
  assert.ok(res.token);
  assert.equal(res.expiresIn, 3600);
});

test('POST /api/voice/incoming returns TwiML with 10s Dial timeout', async () => {
  const res = await makeRawRequest('/api/voice/incoming', 'POST', {
    CallSid: 'CA_test_webhook_01',
    From: '+919876543210'
  });

  assert.ok(res.includes('<Dial timeout="10"'));
  assert.ok(res.includes('<Client>android_user</Client>'));
});

test('POST /api/voice/timeout returns AI Stream Connect TwiML', async () => {
  const res = await makeRawRequest('/api/voice/timeout?callSid=CA_test_webhook_01', 'POST', {
    CallSid: 'CA_test_webhook_01',
    DialCallStatus: 'no-answer'
  });

  assert.ok(res.includes('<Connect>'));
  assert.ok(res.includes('<Stream url='));
  assert.ok(res.includes('/media-stream'));
});

test('POST /api/voice/answered marks call as HUMAN_ANSWERED', async () => {
  const session = getOrCreateSession('CA_answer_01', '+911111111111');
  const res = await makeRequest('/api/voice/answered', 'POST', {
    callSid: 'CA_answer_01'
  });

  assert.equal(res.status, 'HUMAN_ANSWERED');
});

test('POST /api/voice/takeover transfers call from AI to user', async () => {
  const session = getOrCreateSession('CA_takeover_01', '+912222222222');
  session.handleTimeout(); // Put into AI_ANSWERED

  const res = await makeRequest('/api/voice/takeover', 'POST', {
    callSid: 'CA_takeover_01'
  });

  assert.equal(res.status, 'USER_TAKEOVER');
});

test('GET /api/calls returns array of calls with transcripts', async () => {
  const res = await makeRequest('/api/calls', 'GET');
  assert.ok(Array.isArray(res.calls));
  assert.ok(res.calls.length >= 2);
});

// Helper functions for testing Express app using native node http
function makeRequest(path, method, body = null) {
  return new Promise((resolve, reject) => {
    const s = app.listen(0, () => {
      const port = s.address().port;
      const payload = body ? JSON.stringify(body) : null;
      const headers = { 'Content-Type': 'application/json' };
      if (payload) headers['Content-Length'] = Buffer.byteLength(payload);

      const req = require('http').request({
        host: 'localhost',
        port,
        path,
        method,
        headers
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          s.close();
          try {
            resolve(JSON.parse(data));
          } catch (_) {
            resolve(data);
          }
        });
      });

      req.on('error', (err) => {
        s.close();
        reject(err);
      });

      if (payload) req.write(payload);
      req.end();
    });
  });
}

function makeRawRequest(path, method, body = null) {
  return new Promise((resolve, reject) => {
    const s = app.listen(0, () => {
      const port = s.address().port;
      const querystring = require('querystring');
      const payload = body ? querystring.stringify(body) : null;
      const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
      if (payload) headers['Content-Length'] = Buffer.byteLength(payload);

      const req = require('http').request({
        host: 'localhost',
        port,
        path,
        method,
        headers
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          s.close();
          resolve(data);
        });
      });

      req.on('error', (err) => {
        s.close();
        reject(err);
      });

      if (payload) req.write(payload);
      req.end();
    });
  });
}
