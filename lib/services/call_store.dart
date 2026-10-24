import 'package:flutter/material.dart';
import '../models/call_record.dart';

class CallStore extends ChangeNotifier {
  static final CallStore instance = CallStore._();
  CallStore._() {
    _loadInitialRecords();
  }

  final List<CallRecord> _records = [];

  List<CallRecord> get records => List.unmodifiable(_records);

  void addRecord(CallRecord record) {
    _records.insert(0, record);
    notifyListeners();
  }

  void clearRecords() {
    _records.clear();
    notifyListeners();
  }

  void resetInitialRecords() {
    _records.clear();
    _loadInitialRecords();
    notifyListeners();
  }

  void _loadInitialRecords() {
    _records.addAll([
      CallRecord(
        id: 'sample_1',
        callerName: 'Ramesh (Swiggy Delivery)',
        callerNumber: '+91 98765 43210',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        duration: const Duration(seconds: 42),
        category: 'Food Delivery',
        status: CallStatus.aiScreened,
        keyIntent: 'Parcel security guard ke paas drop karwaya gaya (OTP 4920).',
        aiSummary: 'Delivery partner Ramesh ne reach karne par call kiya. AI assistant ne instruction diya ki package main gate guard ko submit karein. Order successfully handed over.',
        urgency: 'Low',
        isSimulated: true,
        hasRecording: true,
        recordingDuration: const Duration(seconds: 42),
        transcript: [
          TranscriptEntry(speaker: 'ai', text: 'Namaste! Main user ka AI Call Assistant hoon. Kahiye kis baare me call kiya hai?'),
          TranscriptEntry(speaker: 'caller', text: 'Bhaiya Swiggy se hoon. Flat 302 par delivery hai, security gate par khada hoon.'),
          TranscriptEntry(speaker: 'ai', text: 'Theek hai Ramesh ji, aap parcel guard ke paas submit kar dijiye aur apna order OTP 4920 bata dijiye.'),
          TranscriptEntry(speaker: 'caller', text: 'Theek hai sir, guard ko parcel handover kar diya hai.'),
          TranscriptEntry(speaker: 'ai', text: 'Dhanyawad Ramesh ji! Have a safe delivery.'),
        ],
      ),
      CallRecord(
        id: 'sample_2',
        callerName: 'Pooja (HDFC Cards)',
        callerNumber: '+91 70001 22334',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
        duration: const Duration(seconds: 28),
        category: 'Promotional',
        status: CallStatus.aiScreened,
        keyIntent: 'Unsolicited credit card offer declined, DND requested.',
        aiSummary: 'Telemarketing executive ne credit card offer pitch kiya. AI assistant ne politely refuse karke phone number ko DND me add karne ka request initiate kiya.',
        urgency: 'None',
        isSimulated: true,
        hasRecording: true,
        recordingDuration: const Duration(seconds: 28),
        transcript: [
          TranscriptEntry(speaker: 'ai', text: 'Namaste! Main AI Assistant hoon. Aap kis vishay par baat karna chahte hain?'),
          TranscriptEntry(speaker: 'caller', text: 'Hello sir, HDFC Bank ki taraf se Lifetime Free Credit Card offer hai.'),
          TranscriptEntry(speaker: 'ai', text: 'Hum is offer me bilkul interested nahi hain. Kripya hamare number ko DND list me daal dijiye.'),
          TranscriptEntry(speaker: 'caller', text: 'Okay sir, main record me update kar deti hoon.'),
          TranscriptEntry(speaker: 'ai', text: 'Dhanyawad. Call disconnect ki ja rahi hai.'),
        ],
      ),
    ]);
  }
}
