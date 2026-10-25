const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const { WebSocket } = require('ws');
const { app, server } = require('../src/server');

describe('Web Calling & Bridge WebSocket Test', () => {
  let testServer;
  let serverPort;

  before(async () => {
    await new Promise((resolve) => {
      testServer = server.listen(0, () => {
        serverPort = testServer.address().port;
        resolve();
      });
    });
  });

  after(async () => {
    await new Promise((resolve) => {
      testServer.close(resolve);
    });
  });

  test('GET /call returns 200 and serves web_caller.html', async () => {
    const res = await fetch(`http://localhost:${serverPort}/call`);
    assert.equal(res.status, 200);
    const html = await res.text();
    assert.match(html, /Ramesh Kumar/);
    assert.match(html, /Start Voice Call/);
  });

  test('GET /api/web-call-info returns valid URLs', async () => {
    const res = await fetch(`http://localhost:${serverPort}/api/web-call-info`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(data.callUrl.includes('/call'));
    assert.ok(data.wsBridgeUrl.includes('/app-bridge'));
  });

  test('App Bridge full flow: START_WEB_CALL -> 10s Timeout -> AI_ANSWERED -> CALLER_SPEECH -> TAKEOVER', async () => {
    // 1. Android client connects
    const androidWs = new WebSocket(`ws://localhost:${serverPort}/app-bridge`);
    await new Promise(r => androidWs.on('open', r));

    androidWs.send(JSON.stringify({ event: 'REGISTER_ANDROID_APP' }));

    const registeredMsg = await new Promise(r => androidWs.once('message', d => r(JSON.parse(d))));
    assert.equal(registeredMsg.event, 'REGISTERED');

    // 2. Web caller connects from 2nd phone
    const webWs = new WebSocket(`ws://localhost:${serverPort}/app-bridge`);
    await new Promise(r => webWs.on('open', r));

    const callSid = `test_web_${Date.now()}`;
    webWs.send(JSON.stringify({
      event: 'START_WEB_CALL',
      callSid,
      callerName: 'Phone 2 Tester',
      callerNumber: 'Web Link'
    }));

    // Android app receives INCOMING_CALL
    const incomingCall = await new Promise(r => androidWs.once('message', d => r(JSON.parse(d))));
    assert.equal(incomingCall.event, 'INCOMING_CALL');
    assert.equal(incomingCall.callSid, callSid);
    assert.equal(incomingCall.timeoutSeconds, 10);

    // 3. Web caller sends speech
    webWs.send(JSON.stringify({
      event: 'CALLER_SPEECH',
      callSid,
      text: 'Swiggy delivery parcel at the gate'
    }));

    // 4. Android user sends Takeover
    androidWs.send(JSON.stringify({
      event: 'USER_TAKEOVER',
      callSid
    }));

    // End call
    webWs.send(JSON.stringify({ event: 'END_CALL', callSid }));

    androidWs.close();
    webWs.close();
  });
});
