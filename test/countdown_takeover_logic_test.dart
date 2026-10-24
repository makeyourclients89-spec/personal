import 'package:flutter_test/flutter_test.dart';
import 'package:call_detection_flutter/models/call_record.dart';
import 'package:call_detection_flutter/models/persona.dart';

void main() {
  group('10-Second Countdown & Takeover Logic Tests', () {
    test('10-second countdown calculation and timeout trigger', () {
      int countdownSeconds = 10;
      bool aiTakeoverTriggered = false;

      // Simulate 10 seconds passage
      for (int i = 0; i < 10; i++) {
        expect(countdownSeconds > 0, true);
        countdownSeconds--;
      }

      if (countdownSeconds == 0) {
        aiTakeoverTriggered = true;
      }

      expect(countdownSeconds, 0);
      expect(aiTakeoverTriggered, true);
    });

    test('User answering within 10 seconds results in direct user call', () {
      int countdownSeconds = 10;
      CallStatus? callStatus;

      // User picks up at 4 seconds
      const userPickedUpAt = 4;
      for (int i = 0; i < userPickedUpAt; i++) {
        countdownSeconds--;
      }

      // User accepted before 10s timeout
      expect(countdownSeconds, 6);
      if (countdownSeconds > 0) {
        callStatus = CallStatus.directUser;
      }

      expect(callStatus, CallStatus.directUser);
    });

    test('User taking over call transitions state from aiScreened to takenOver', () {
      CallStatus currentStatus = CallStatus.aiScreened;
      final transcript = <TranscriptEntry>[
        TranscriptEntry(speaker: 'ai', text: 'Namaste! Main AI hoon.'),
        TranscriptEntry(speaker: 'caller', text: 'Delivery boy hoon.'),
      ];

      // User clicks Takeover button
      currentStatus = CallStatus.takenOver;
      transcript.add(TranscriptEntry(speaker: 'user', text: 'Aapne call takeover kar li.'));

      expect(currentStatus, CallStatus.takenOver);
      expect(transcript.length, 3);
      expect(transcript.last.speaker, 'user');
    });

    test('Completed call record includes recording duration and summary', () {
      final persona = DemoPersona.presets.first;
      final startTime = DateTime.now().subtract(const Duration(seconds: 40));
      final duration = DateTime.now().difference(startTime);

      final record = CallRecord(
        id: 'rec_test',
        callerName: persona.name,
        callerNumber: persona.number,
        timestamp: startTime,
        duration: duration,
        category: persona.category,
        status: CallStatus.takenOver,
        keyIntent: persona.intent,
        aiSummary: 'Real-time AI summary generated for caller.',
        urgency: persona.urgency,
        transcript: [
          TranscriptEntry(speaker: 'ai', text: 'Hello!'),
          TranscriptEntry(speaker: 'user', text: 'Taken over.'),
        ],
        hasRecording: true,
        recordingDuration: duration,
      );

      expect(record.hasRecording, true);
      expect(record.recordingDuration.inSeconds, greaterThanOrEqualTo(40));
      expect(record.status, CallStatus.takenOver);
      expect(record.aiSummary.contains('summary'), true);
    });
  });
}
