const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const { CallSession, CallState } = require('./state_machine');
const { AiVoiceAgent } = require('./ai_voice_agent');
const callStorage = require('./call_storage');
const twilioClient = require('./twilio_client');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/media-stream' });

// In-memory active call sessions
const activeSessions = new Map();

// Helper to get or create session
function getOrCreateSession(callSid, callerNumber = 'Unknown') {
  if (!activeSessions.has(callSid)) {
    const session = new CallSession(callSid, callerNumber, 'android_user', { timeoutSeconds: 10 });
    activeSessions.set(callSid, session);
  }
  return activeSessions.get(callSid);
}

// 1. Health Endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    activeSessions: activeSessions.size,
    timestamp: new Date().toISOString()
  });
});

// 2. VoIP Access Token for Android Client
app.get('/api/token', (req, res) => {
  const identity = req.query.identity || 'android_user';
  const token = twilioClient.generateClientToken(identity);
  res.json({
    identity,
    token,
    expiresIn: 3600
  });
});

// 3. Inbound Call Webhook (Twilio Entry Point)
app.post('/api/voice/incoming', (req, res) => {
  const callSid = req.body.CallSid || `call_${Date.now()}`;
  const callerNumber = req.body.From || '+919876543210';
  const host = `${req.protocol}://${req.get('host')}`;

  const session = getOrCreateSession(callSid, callerNumber);

  // Server-side 10-second timeout enforcement
  session.startTimeout((timedOutSession) => {
    // If not answered by human, timeout triggers
    console.log(`[Timeout] 10 seconds expired for call ${timedOutSession.callSid}. Routing to AI voice agent.`);
  });

  res.type('text/xml');
  res.send(twilioClient.buildIncomingCallTwiML(host, { timeoutSeconds: 10 }));
});

// 4. Dial Timeout Action (Triggered after 10s if user does not answer)
app.post('/api/voice/timeout', (req, res) => {
  const callSid = req.body.CallSid || req.query.callSid;
  const dialCallStatus = req.body.DialCallStatus; // 'no-answer', 'busy', 'completed'
  const session = activeSessions.get(callSid);

  const protocol = req.protocol === 'https' ? 'wss' : 'ws';
  const wsHost = `${protocol}://${req.get('host')}`;

  res.type('text/xml');

  // If user answered within 10s, DialCallStatus is 'completed'
  if (dialCallStatus === 'completed' || (session && session.state === CallState.HUMAN_ANSWERED)) {
    if (session) session.complete();
    return res.send('<Response><Hangup /></Response>');
  }

  // Otherwise, 10s timeout occurred -> Connect to AI Media Stream!
  if (session) {
    session.handleTimeout();
  }

  res.send(twilioClient.buildAiStreamTwiML(wsHost));
});

// 5. User Answered Hook (Called when Android user answers before 10s)
app.post('/api/voice/answered', (req, res) => {
  const { callSid } = req.body;
  const session = activeSessions.get(callSid);

  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }

  const success = session.userAnswer();
  if (success) {
    res.json({ status: 'HUMAN_ANSWERED', message: 'User connected. AI fallback cancelled.' });
  } else {
    res.status(409).json({ status: session.state, message: 'Call already handled or expired.' });
  }
});

// 6. User Takeover Hook (Called when Android user taps "Take Over Call" during AI conversation)
app.post('/api/voice/takeover', (req, res) => {
  const { callSid } = req.body;
  const session = activeSessions.get(callSid);

  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }

  const success = session.userTakeover();
  if (success) {
    // If AI agent was active on WebSocket, it stops
    res.json({
      status: 'USER_TAKEOVER',
      message: 'Call transferred from AI Assistant to Android user.'
    });
  } else {
    res.status(400).json({
      status: session.state,
      message: 'Cannot takeover call in current state.'
    });
  }
});

// 7. Call Status & Recording Callback
app.post('/api/voice/recording', (req, res) => {
  const callSid = req.body.CallSid;
  const recordingUrl = req.body.RecordingUrl;

  if (callSid && recordingUrl) {
    callStorage.updateRecording(callSid, recordingUrl);
    const session = activeSessions.get(callSid);
    if (session) {
      session.recordingUrl = recordingUrl;
    }
  }

  res.sendStatus(200);
});

// 8. List Calls History & Recordings
app.get('/api/calls', (req, res) => {
  // Sync active sessions to storage
  for (const session of activeSessions.values()) {
    callStorage.save(session.toJSON());
  }
  res.json({
    calls: callStorage.getAll()
  });
});

// 9. Single Call Detail
app.get('/api/calls/:callSid', (req, res) => {
  const session = activeSessions.get(req.params.callSid);
  if (session) {
    return res.json(session.toJSON());
  }

  const stored = callStorage.get(req.params.callSid);
  if (stored) {
    return res.json(stored);
  }

  res.status(404).json({ error: 'Call not found' });
});

// WebSocket Handler for Real-Time Bidirectional AI Media Streaming
wss.on('connection', (ws) => {
  let agent = null;

  ws.on('message', (message) => {
    try {
      const parsed = JSON.parse(message);
      if (parsed.event === 'start') {
        const callSid = parsed.start.callSid;
        const session = getOrCreateSession(callSid);
        session.state = CallState.AI_ANSWERED;
        agent = new AiVoiceAgent(session, ws);
      }

      if (agent) {
        agent.handleWebSocketMessage(message);
      }
    } catch (_) {}
  });

  ws.on('close', () => {
    if (agent && agent.session) {
      agent.session.complete();
      callStorage.save(agent.session.toJSON());
    }
  });
});

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`[AI Call Assistant Server] running on http://localhost:${PORT}`);
    console.log(`[Media Stream WebSocket] listening on ws://localhost:${PORT}/media-stream`);
  });
}

module.exports = { app, server, activeSessions, getOrCreateSession };
