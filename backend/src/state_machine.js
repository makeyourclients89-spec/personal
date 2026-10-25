/**
 * Call State Machine with Server-Side 10s Timeout & Race Condition Protection
 */

const CallState = {
  RINGING: 'RINGING',
  HUMAN_ANSWERED: 'HUMAN_ANSWERED',
  AI_ANSWERED: 'AI_ANSWERED',
  USER_TAKEOVER: 'USER_TAKEOVER',
  DECLINED: 'DECLINED',
  NO_ANSWER: 'NO_ANSWER',
  COMPLETED: 'COMPLETED',
  FAILED: 'FAILED'
};

class CallSession {
  constructor(callSid, callerNumber, destination = 'android_user', options = {}) {
    this.callSid = callSid;
    this.callerNumber = callerNumber || 'Unknown';
    this.destination = destination;
    this.state = CallState.RINGING;
    this.createdAt = new Date();
    this.answeredAt = null;
    this.endedAt = null;
    this.timeoutSeconds = options.timeoutSeconds || 10;
    this.timeoutTimer = null;
    this.streamSid = null;
    this.transcript = [];
    this.aiSummary = '';
    this.keyIntent = '';
    this.urgency = 'Medium';
    this.category = 'General';
    this.recordingUrl = null;
    this.isLocked = false; // Mutex lock for race-condition prevention
  }

  startTimeout(onTimeoutCallback) {
    if (this.timeoutTimer) clearTimeout(this.timeoutTimer);
    this.timeoutTimer = setTimeout(() => {
      this.handleTimeout(onTimeoutCallback);
    }, this.timeoutSeconds * 1000);
  }

  cancelTimeout() {
    if (this.timeoutTimer) {
      clearTimeout(this.timeoutTimer);
      this.timeoutTimer = null;
    }
  }

  handleTimeout(callback) {
    if (this.isLocked) return;
    this.isLocked = true;

    try {
      if (this.state === CallState.RINGING) {
        this.state = CallState.AI_ANSWERED;
        this.answeredAt = new Date();
        if (callback) callback(this);
      }
    } finally {
      this.isLocked = false;
    }
  }

  userAnswer() {
    if (this.isLocked) return false;
    this.isLocked = true;

    try {
      if (this.state === CallState.RINGING) {
        this.cancelTimeout();
        this.state = CallState.HUMAN_ANSWERED;
        this.answeredAt = new Date();
        return true;
      }
      return false; // Already answered by AI or declined
    } finally {
      this.isLocked = false;
    }
  }

  userTakeover() {
    if (this.isLocked) return false;
    this.isLocked = true;

    try {
      if (this.state === CallState.AI_ANSWERED) {
        this.state = CallState.USER_TAKEOVER;
        this.transcript.push({
          speaker: 'user',
          text: '[Takeover] User took over the live call from AI Assistant.',
          timestamp: new Date().toISOString()
        });
        return true;
      }
      return false;
    } finally {
      this.isLocked = false;
    }
  }

  decline() {
    this.cancelTimeout();
    this.state = CallState.DECLINED;
    this.endedAt = new Date();
  }

  complete() {
    this.cancelTimeout();
    this.state = CallState.COMPLETED;
    this.endedAt = new Date();
  }

  getDurationSeconds() {
    const start = this.answeredAt || this.createdAt;
    const end = this.endedAt || new Date();
    return Math.max(0, Math.round((end - start) / 1000));
  }

  addTranscript(speaker, text) {
    this.transcript.push({
      speaker,
      text,
      timestamp: new Date().toISOString()
    });
  }

  toJSON() {
    return {
      callSid: this.callSid,
      callerNumber: this.callerNumber,
      destination: this.destination,
      state: this.state,
      createdAt: this.createdAt.toISOString(),
      answeredAt: this.answeredAt ? this.answeredAt.toISOString() : null,
      endedAt: this.endedAt ? this.endedAt.toISOString() : null,
      durationSeconds: this.getDurationSeconds(),
      category: this.category,
      urgency: this.urgency,
      keyIntent: this.keyIntent,
      aiSummary: this.aiSummary,
      recordingUrl: this.recordingUrl,
      transcript: this.transcript
    };
  }
}

module.exports = {
  CallState,
  CallSession
};
