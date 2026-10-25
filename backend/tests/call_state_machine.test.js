const test = require('node:test');
const assert = require('node:assert/strict');
const { CallSession, CallState } = require('../src/state_machine');

test('CallSession initializes with RINGING state and 10s timeout', () => {
  const session = new CallSession('CA_test_01', '+919876543210', 'android_user', { timeoutSeconds: 10 });
  assert.equal(session.state, CallState.RINGING);
  assert.equal(session.timeoutSeconds, 10);
  assert.equal(session.callerNumber, '+919876543210');
});

test('User answering within timeout cancels timeout and sets HUMAN_ANSWERED', () => {
  const session = new CallSession('CA_test_02', '+919876543210', 'android_user', { timeoutSeconds: 10 });
  let timeoutFired = false;

  session.startTimeout(() => {
    timeoutFired = true;
  });

  const success = session.userAnswer();
  assert.equal(success, true);
  assert.equal(session.state, CallState.HUMAN_ANSWERED);
  assert.equal(timeoutFired, false);
});

test('Timeout fires after configured seconds and transitions to AI_ANSWERED', (t, done) => {
  // Use 100ms for fast unit test
  const session = new CallSession('CA_test_03', '+919876543210', 'android_user', { timeoutSeconds: 0.1 });
  let timeoutTriggered = false;

  session.startTimeout((s) => {
    timeoutTriggered = true;
    assert.equal(s.state, CallState.AI_ANSWERED);
    assert.equal(timeoutTriggered, true);
    done();
  });
});

test('User takeover transitions state from AI_ANSWERED to USER_TAKEOVER', () => {
  const session = new CallSession('CA_test_04', '+919876543210', 'android_user', { timeoutSeconds: 10 });
  session.handleTimeout(); // AI answers

  assert.equal(session.state, CallState.AI_ANSWERED);

  const takeoverSuccess = session.userTakeover();
  assert.equal(takeoverSuccess, true);
  assert.equal(session.state, CallState.USER_TAKEOVER);
  assert.equal(session.transcript.length, 1);
  assert.equal(session.transcript[0].speaker, 'user');
});

test('Race condition: userAnswer fails if call already timed out to AI_ANSWERED', () => {
  const session = new CallSession('CA_test_05', '+919876543210', 'android_user', { timeoutSeconds: 10 });
  session.handleTimeout(); // Timed out

  const answerAttempt = session.userAnswer();
  assert.equal(answerAttempt, false);
  assert.equal(session.state, CallState.AI_ANSWERED);
});
