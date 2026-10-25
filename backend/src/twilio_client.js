/**
 * Twilio Voice TwiML Generator & Token Service
 */

class TwilioVoiceClient {
  constructor(config = {}) {
    this.accountSid = config.accountSid || process.env.TWILIO_ACCOUNT_SID || 'AC_DEMO_ACCOUNT_SID';
    this.apiKey = config.apiKey || process.env.TWILIO_API_KEY || 'SK_DEMO_API_KEY';
    this.apiSecret = config.apiSecret || process.env.TWILIO_API_SECRET || 'DEMO_SECRET';
    this.appSid = config.appSid || process.env.TWILIO_TWIML_APP_SID || 'AP_DEMO_APP_SID';
  }

  generateClientToken(identity = 'android_user', ttl = 3600) {
    // Generate simulated or standard JWT token for Twilio Voice Android SDK
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({
      jti: `${this.apiKey}-${Date.now()}`,
      iss: this.apiKey,
      sub: this.accountSid,
      exp: Math.floor(Date.now() / 1000) + ttl,
      grants: {
        identity,
        voice: {
          incoming: { allow: true },
          outgoing: { application_sid: this.appSid }
        }
      }
    })).toString('base64url');

    return `${header}.${payload}.DEMO_SIGNATURE`;
  }

  buildIncomingCallTwiML(host, options = {}) {
    const timeout = options.timeoutSeconds || 10;
    const clientIdentity = options.clientIdentity || 'android_user';

    return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Dial timeout="${timeout}" action="${host}/api/voice/timeout" record="record-from-answer-dual" recordingStatusCallback="${host}/api/voice/recording">
        <Client>${clientIdentity}</Client>
    </Dial>
</Response>`;
  }

  buildAiStreamTwiML(wsHost) {
    return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Connect>
        <Stream url="${wsHost}/media-stream">
            <Parameter name="aiAgent" value="true" />
        </Stream>
    </Connect>
</Response>`;
  }

  buildTakeoverTwiML(clientIdentity = 'android_user') {
    return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Dial>
        <Client>${clientIdentity}</Client>
    </Dial>
</Response>`;
  }
}

module.exports = new TwilioVoiceClient();
