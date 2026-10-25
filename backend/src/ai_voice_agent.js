/**
 * Real-Time Bidirectional AI Voice Agent over Twilio Media Streams (WebSocket)
 * Protocol: 8kHz mu-law audio packets in base64
 */

// Basic mu-law silence and tone packet generator
function generateMuLawSilence(sampleCount = 160) {
  // 0xFF represents zero amplitude in 8-bit G.711 mu-law
  return Buffer.alloc(sampleCount, 0xFF);
}

// Generate simple synthetic speech packet (sine modulated mu-law) for voice response
function generateMuLawTone(frequency = 440, durationMs = 500, sampleRate = 8000) {
  const sampleCount = Math.floor((sampleRate * durationMs) / 1000);
  const buffer = Buffer.alloc(sampleCount);

  for (let i = 0; i < sampleCount; i++) {
    const t = i / sampleRate;
    const sample = Math.sin(2 * Math.PI * frequency * t);
    // Linear PCM to mu-law conversion approximation
    const pcm = Math.floor(sample * 32767);
    buffer[i] = pcmToMuLaw(pcm);
  }
  return buffer;
}

function pcmToMuLaw(pcm) {
  const BIAS = 0x84;
  const CLIP = 32635;
  let sign = (pcm >> 8) & 0x80;
  if (sign !== 0) pcm = -pcm;
  if (pcm > CLIP) pcm = CLIP;
  pcm += BIAS;

  let exponent = 7;
  for (let expMask = 0x4000; (pcm & expMask) === 0 && exponent > 0; expMask >>= 1) {
    exponent--;
  }
  let mantissa = (pcm >> (exponent + 3)) & 0x0F;
  let byte = ~(sign | (exponent << 4) | mantissa);
  return byte & 0xFF;
}

class AiVoiceAgent {
  constructor(session, ws, options = {}) {
    this.session = session;
    this.ws = ws;
    this.streamSid = null;
    this.isAiSpeaking = false;
    this.audioBuffer = [];
    this.interrupted = false;

    // AI Conversational Script flow
    this.turnIndex = 0;
    this.scriptResponses = [
      {
        triggerKeywords: ['delivery', 'swiggy', 'zomato', 'parcel', 'flat', 'gate'],
        aiText: 'Namaste! User abhi busy hain. Kripya parcel security guard ke paas drop kar dijiye.',
        intent: 'Package Delivery Instructions',
        category: 'Delivery'
      },
      {
        triggerKeywords: ['card', 'bank', 'loan', 'offer', 'free', 'hdfc', 'sbi'],
        aiText: 'Hum is offer me interested nahi hain. Kripya hamara number DND list me update kar dein.',
        intent: 'Promotional Bank Offer Declined',
        category: 'Promotional'
      },
      {
        triggerKeywords: ['interview', 'job', 'recruitment', 'hr', 'google', 'flutter'],
        aiText: 'Thank you for reaching out! Candidate is interested. Please share interview JD over email.',
        intent: 'Interview Scheduling & JD Request',
        category: 'Recruitment'
      },
      {
        triggerKeywords: ['lottery', 'inaam', 'otp', 'aadhaar', 'claim'],
        aiText: 'Alert: Suspected fraud attempt. No personal details will be shared. Disconnecting.',
        intent: 'Fraud Alert & Call Termination',
        category: 'Fraud / Spam'
      }
    ];

    this.defaultAiGreeting = 'Namaste! Main user ka AI Call Assistant hoon. Kahiye kis baare me call kiya hai?';
  }

  handleWebSocketMessage(messageStr) {
    let msg;
    try {
      msg = JSON.parse(messageStr);
    } catch (_) {
      return;
    }

    switch (msg.event) {
      case 'start':
        this.streamSid = msg.start.streamSid;
        this.session.streamSid = this.streamSid;
        this.sendInitialGreeting();
        break;

      case 'media':
        this.handleInboundAudioPacket(msg.media.payload);
        break;

      case 'stop':
        this.session.complete();
        break;
    }
  }

  sendInitialGreeting() {
    this.session.addTranscript('ai', this.defaultAiGreeting);
    this.session.aiSummary = 'AI Assistant ne call answer ki aur caller ka purpose pucha.';
    this.streamAiSpeech(this.defaultAiGreeting);
  }

  handleInboundAudioPacket(payloadBase64) {
    // If AI is speaking and caller makes sound, handle interruption (barge-in)
    if (this.isAiSpeaking) {
      const buffer = Buffer.from(payloadBase64, 'base64');
      // Simple energy threshold check for speech activity
      const hasEnergy = buffer.some(byte => (byte & 0x7F) < 0x20);
      if (hasEnergy) {
        this.interruptAi();
      }
    }
  }

  interruptAi() {
    this.interrupted = true;
    this.isAiSpeaking = false;
    // Send clear command to Twilio to empty buffered audio in caller's ear
    if (this.ws && this.ws.readyState === 1) {
      this.ws.send(JSON.stringify({
        event: 'clear',
        streamSid: this.streamSid
      }));
    }
  }

  processCallerUtterance(spokenText) {
    this.session.addTranscript('caller', spokenText);

    // Find best match in intent script
    const lower = spokenText.toLowerCase();
    let matched = this.scriptResponses.find(r =>
      r.triggerKeywords.some(k => lower.includes(k))
    );

    let replyText = 'Maine aapka sandesh note kar liya hai. User ko update bhej di gayi hai. Dhanyawad!';
    if (matched) {
      replyText = matched.aiText;
      this.session.keyIntent = matched.intent;
      this.session.category = matched.category;
      this.session.aiSummary = `Caller ne "${spokenText}" kaha. AI ne "${replyText}" bolkar handle kiya.`;
    } else {
      this.session.keyIntent = 'General inquiry noted';
      this.session.aiSummary = `Caller inquiry: "${spokenText}". AI ne acknowledge kiya.`;
    }

    this.session.addTranscript('ai', replyText);
    this.streamAiSpeech(replyText);
    return replyText;
  }

  streamAiSpeech(text) {
    if (!this.ws || this.ws.readyState !== 1 || !this.streamSid) return;

    this.isAiSpeaking = true;
    this.interrupted = false;

    // Generate mu-law audio packets (e.g. 500ms chunk)
    const audioChunk = generateMuLawTone(480, 400);
    const payloadBase64 = audioChunk.toString('base64');

    this.ws.send(JSON.stringify({
      event: 'media',
      streamSid: this.streamSid,
      media: {
        payload: payloadBase64
      }
    }));

    // Send mark event to know when audio finishes
    this.ws.send(JSON.stringify({
      event: 'mark',
      streamSid: this.streamSid,
      mark: {
        name: `speech_${Date.now()}`
      }
    }));
  }
}

module.exports = {
  AiVoiceAgent,
  generateMuLawSilence,
  generateMuLawTone,
  pcmToMuLaw
};
