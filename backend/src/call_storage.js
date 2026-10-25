/**
 * Call Storage & Persistence Layer
 */

class CallStorage {
  constructor() {
    this.calls = new Map();
    this.seedDefaultRecords();
  }

  seedDefaultRecords() {
    this.save({
      callSid: 'CA_sample_delivery_01',
      callerNumber: '+91 98765 43210',
      destination: 'android_user',
      state: 'COMPLETED',
      createdAt: new Date(Date.now() - 35 * 60000).toISOString(),
      answeredAt: new Date(Date.now() - 34 * 60000).toISOString(),
      endedAt: new Date(Date.now() - 33 * 60000).toISOString(),
      durationSeconds: 46,
      category: 'Food Delivery',
      urgency: 'Low',
      keyIntent: 'Parcel security guard ke paas drop karwaya gaya.',
      aiSummary: 'Swiggy delivery partner ne gate se call kiya. AI assistant ne OTP 4920 confirm karke packet guard ko handover karwaya.',
      recordingUrl: 'https://api.twilio.com/2010-04-01/Accounts/AC_DEMO/Recordings/RE_sample_01.wav',
      transcript: [
        { speaker: 'ai', text: 'Namaste! Main user ka AI Call Assistant hoon. Kahiye kis baare me call kiya hai?', timestamp: '00:02' },
        { speaker: 'caller', text: 'Bhaiya Swiggy se hoon. Flat 302 par delivery hai, security gate par khada hoon.', timestamp: '00:08' },
        { speaker: 'ai', text: 'Theek hai Ramesh ji, aap parcel guard ke paas submit kar dijiye aur apna order OTP 4920 bata dijiye.', timestamp: '00:18' },
        { speaker: 'caller', text: 'Theek hai sir, guard ko parcel de diya hai.', timestamp: '00:32' },
        { speaker: 'ai', text: 'Dhanyawad Ramesh ji! Have a safe delivery.', timestamp: '00:40' }
      ]
    });

    this.save({
      callSid: 'CA_sample_telemarketer_02',
      callerNumber: '+91 70001 22334',
      destination: 'android_user',
      state: 'COMPLETED',
      createdAt: new Date(Date.now() - 2 * 3600000).toISOString(),
      answeredAt: new Date(Date.now() - 2 * 3600000 + 10000).toISOString(),
      endedAt: new Date(Date.now() - 2 * 3600000 + 38000).toISOString(),
      durationSeconds: 28,
      category: 'Promotional',
      urgency: 'None',
      keyIntent: 'Unsolicited credit card offer declined, DND requested.',
      aiSummary: 'Telemarketing executive ne credit card offer pitch kiya. AI assistant ne politely refuse karke phone number ko DND me add karne ka request initiate kiya.',
      recordingUrl: 'https://api.twilio.com/2010-04-01/Accounts/AC_DEMO/Recordings/RE_sample_02.wav',
      transcript: [
        { speaker: 'ai', text: 'Namaste! Main AI Assistant hoon. Aap kis vishay par baat karna chahte hain?', timestamp: '00:02' },
        { speaker: 'caller', text: 'Hello sir, HDFC Bank ki taraf se Lifetime Free Credit Card offer hai.', timestamp: '00:09' },
        { speaker: 'ai', text: 'Hum is offer me bilkul interested nahi hain. Kripya hamare number ko DND list me daal dijiye.', timestamp: '00:17' },
        { speaker: 'caller', text: 'Okay sir, main record me update kar deti hoon.', timestamp: '00:23' },
        { speaker: 'ai', text: 'Dhanyawad. Call disconnect ki ja rahi hai.', timestamp: '00:27' }
      ]
    });
  }

  save(callData) {
    const sid = callData.callSid || `call_${Date.now()}`;
    this.calls.set(sid, callData);
    return callData;
  }

  get(callSid) {
    return this.calls.get(callSid) || null;
  }

  getAll() {
    return Array.from(this.calls.values()).sort((a, b) => {
      return new Date(b.createdAt) - new Date(a.createdAt);
    });
  }

  updateRecording(callSid, recordingUrl) {
    const call = this.get(callSid);
    if (call) {
      call.recordingUrl = recordingUrl;
      this.calls.set(callSid, call);
      return call;
    }
    return null;
  }
}

module.exports = new CallStorage();
