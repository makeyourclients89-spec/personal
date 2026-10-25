const express = require('express');
const http = require('http');
const path = require('path');
const { WebSocketServer } = require('ws');
const { CallSession, CallState } = require('./state_machine');
const { AiVoiceAgent } = require('./ai_voice_agent');
const callStorage = require('./call_storage');
const twilioClient = require('./twilio_client');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const server = http.createServer(app);
const wssMedia = new WebSocketServer({ noServer: true });
const wssBridge = new WebSocketServer({ noServer: true });

server.on('upgrade', (request, socket, head) => {
  try {
    const parsedUrl = new URL(request.url, `http://${request.headers.host}`);
    if (parsedUrl.pathname === '/media-stream') {
      wssMedia.handleUpgrade(request, socket, head, (ws) => {
        wssMedia.emit('connection', ws, request);
      });
    } else if (parsedUrl.pathname === '/app-bridge') {
      wssBridge.handleUpgrade(request, socket, head, (ws) => {
        wssBridge.emit('connection', ws, request);
      });
    } else {
      socket.destroy();
    }
  } catch (_) {
    socket.destroy();
  }
});

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

// 10. Web Calling UI & Call Info Endpoints (Free testing without Twilio)
app.get('/call', (req, res) => {
  res.sendFile(path.join(__dirname, 'web_caller.html'));
});

app.get('/api/web-call-info', (req, res) => {
  const host = req.get('host') || 'localhost:3000';
  const protocol = req.protocol || 'http';
  res.json({
    callUrl: `${protocol}://${host}/call`,
    wsBridgeUrl: `${protocol === 'https' ? 'wss' : 'ws'}://${host}/app-bridge`
  });
});

// WebSocket Handler 1: Twilio Media Streaming (/media-stream)
wssMedia.on('connection', (ws) => {
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

// WebSocket Handler 2: App & Web Signaling Bridge (/app-bridge)
const androidClients = new Set();
const webCallSessions = new Map();

wssBridge.on('connection', (ws) => {
  let boundCallSid = null;

  ws.on('message', (raw) => {
    try {
      const data = JSON.parse(raw);

      // Register Android App
      if (data.event === 'REGISTER_ANDROID_APP') {
        androidClients.add(ws);
        ws.send(JSON.stringify({ event: 'REGISTERED', status: 'ready' }));
        return;
      }

      // Web Caller initiates call
      if (data.event === 'START_WEB_CALL') {
        const callSid = data.callSid || `web_${Date.now()}`;
        boundCallSid = callSid;
        const callerName = data.callerName || 'Web Caller (Phone 2)';
        const callerNumber = data.callerNumber || 'Free Calling Link';

        const session = getOrCreateSession(callSid, callerNumber);
        session.callerName = callerName;
        const agent = new AiVoiceAgent(session, null);

        webCallSessions.set(callSid, { webWs: ws, session, agent });

        // Broadcast INCOMING_CALL to all connected Android apps
        const incomingPayload = JSON.stringify({
          event: 'INCOMING_CALL',
          callSid,
          callerName,
          callerNumber,
          timeoutSeconds: 10
        });
        for (const appWs of androidClients) {
          if (appWs.readyState === 1) appWs.send(incomingPayload);
        }

        // Start server-controlled 10-second timeout
        session.startTimeout((timedOutSession) => {
          const active = webCallSessions.get(callSid);
          if (active && active.session.state === CallState.AI_ANSWERED) {
            const greeting = agent.defaultAiGreeting;
            active.session.addTranscript('ai', greeting);

            // Notify Web Caller that AI answered
            if (active.webWs.readyState === 1) {
              active.webWs.send(JSON.stringify({
                event: 'AI_ANSWERED',
                callSid,
                greeting
              }));
            }

            // Notify Android App that AI is screening
            const aiNotify = JSON.stringify({
              event: 'AI_ANSWERED',
              callSid,
              greeting,
              transcripts: active.session.transcripts
            });
            for (const appWs of androidClients) {
              if (appWs.readyState === 1) appWs.send(aiNotify);
            }
          }
        });
        return;
      }

      // Android user answers before 10s
      if (data.event === 'USER_ANSWER') {
        const callSid = data.callSid;
        const active = webCallSessions.get(callSid);
        if (active) {
          const success = active.session.userAnswer();
          if (success && active.webWs.readyState === 1) {
            active.webWs.send(JSON.stringify({ event: 'HUMAN_ANSWERED', callSid }));
          }
        }
        return;
      }

      // Web Caller speaks (STT text)
      if (data.event === 'CALLER_SPEECH') {
        const callSid = data.callSid;
        const active = webCallSessions.get(callSid);
        if (active && active.session.state === CallState.AI_ANSWERED) {
          const reply = active.agent.processCallerUtterance(data.text);

          // Reply back to Web Caller (Phone 2)
          if (active.webWs.readyState === 1) {
            active.webWs.send(JSON.stringify({
              event: 'AI_RESPONSE',
              callSid,
              text: reply
            }));
          }

          // Broadcast transcript update to Android App
          const transcriptPayload = JSON.stringify({
            event: 'TRANSCRIPT_UPDATE',
            callSid,
            callerText: data.text,
            aiText: reply,
            transcripts: active.session.transcripts
          });
          for (const appWs of androidClients) {
            if (appWs.readyState === 1) appWs.send(transcriptPayload);
          }
        }
        return;
      }

      // Android user taps "Take Over Call"
      if (data.event === 'USER_TAKEOVER') {
        const callSid = data.callSid;
        const active = webCallSessions.get(callSid);
        if (active) {
          active.session.userTakeover();
          if (active.webWs.readyState === 1) {
            active.webWs.send(JSON.stringify({ event: 'USER_TAKEOVER', callSid }));
          }
        }
        return;
      }

      // Call Ended
      if (data.event === 'END_CALL') {
        const callSid = data.callSid || boundCallSid;
        const active = webCallSessions.get(callSid);
        if (active) {
          active.session.complete();
          callStorage.save(active.session.toJSON());
          webCallSessions.delete(callSid);
          for (const appWs of androidClients) {
            if (appWs.readyState === 1) {
              appWs.send(JSON.stringify({ event: 'CALL_ENDED', callSid }));
            }
          }
        }
        return;
      }

    } catch (err) {
      console.error('[App Bridge Error]', err);
    }
  });

  ws.on('close', () => {
    androidClients.delete(ws);
    if (boundCallSid && webCallSessions.has(boundCallSid)) {
      const active = webCallSessions.get(boundCallSid);
      active.session.complete();
      callStorage.save(active.session.toJSON());
      webCallSessions.delete(boundCallSid);
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
