const test = require('node:test');
const assert = require('node:assert/strict');
const { AiVoiceAgent, generateMuLawSilence, generateMuLawTone, pcmToMuLaw } = require('../src/ai_voice_agent');
const { CallSession } = require('../src/state_machine');

class MockWebSocket {
  constructor() {
    this.sent = [];
    this.readyState = 1; // OPEN
  }
  send(data) {
    this.sent.push(JSON.parse(data));
  }
}

test('generateMuLawSilence produces 0xFF buffer', () => {
  const silence = generateMuLawSilence(160);
  assert.equal(silence.length, 160);
  assert.equal(silence[0], 0xFF);
});

test('generateMuLawTone generates valid tone buffer', () => {
  const tone = generateMuLawTone(440, 100);
  assert.equal(tone.length, 800); // 8000Hz * 0.1s
});

test('AiVoiceAgent handles start event and sends initial greeting audio', () => {
  const session = new CallSession('CA_stream_01', '+919999999999');
  const mockWs = new MockWebSocket();
  const agent = new AiVoiceAgent(session, mockWs);

  agent.handleWebSocketMessage(JSON.stringify({
    event: 'start',
    start: {
      streamSid: 'MZ_12345',
      callSid: 'CA_stream_01'
    }
  }));

  assert.equal(agent.streamSid, 'MZ_12345');
  assert.equal(session.transcript.length, 1);
  assert.equal(session.transcript[0].speaker, 'ai');

  // Verify audio packets and mark event were sent to Twilio
  const mediaEvents = mockWs.sent.filter(m => m.event === 'media');
  assert.ok(mediaEvents.length > 0);
  assert.equal(mediaEvents[0].streamSid, 'MZ_12345');
});

test('AiVoiceAgent matches delivery keywords and responds accordingly', () => {
  const session = new CallSession('CA_stream_02', '+919999999999');
  const mockWs = new MockWebSocket();
  const agent = new AiVoiceAgent(session, mockWs);
  agent.streamSid = 'MZ_12345';

  agent.processCallerUtterance('Bhaiya main Swiggy delivery se hoon gate par');

  assert.equal(session.category, 'Delivery');
  assert.ok(session.transcript.some(t => t.speaker === 'caller'));
  assert.ok(session.transcript.some(t => t.speaker === 'ai' && t.text.includes('guard')));
});

test('AiVoiceAgent clears buffer on barge-in interruption', () => {
  const session = new CallSession('CA_stream_03', '+919999999999');
  const mockWs = new MockWebSocket();
  const agent = new AiVoiceAgent(session, mockWs);
  agent.streamSid = 'MZ_12345';
  agent.isAiSpeaking = true;

  // Simulate loud packet from caller (audio with energy)
  const loudAudio = Buffer.alloc(160, 0x10).toString('base64');
  agent.handleInboundAudioPacket(loudAudio);

  assert.equal(agent.interrupted, true);
  assert.equal(agent.isAiSpeaking, false);
  const clearEvent = mockWs.sent.find(m => m.event === 'clear');
  assert.ok(clearEvent);
  assert.equal(clearEvent.streamSid, 'MZ_12345');
});
