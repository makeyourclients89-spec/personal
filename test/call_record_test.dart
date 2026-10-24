import 'package:flutter_test/flutter_test.dart';
import 'package:call_detection_flutter/models/call_record.dart';

void main() {
  group('CallRecord & TranscriptEntry Tests', () {
    test('TranscriptEntry serialization and deserialization works correctly', () {
      final entry = TranscriptEntry(
        speaker: 'ai',
        text: 'Namaste! Main AI Assistant hoon.',
      );

      final json = entry.toJson();
      expect(json['speaker'], 'ai');
      expect(json['text'], 'Namaste! Main AI Assistant hoon.');
      expect(json['timestamp'], isNotNull);

      final restored = TranscriptEntry.fromJson(json);
      expect(restored.speaker, 'ai');
      expect(restored.text, 'Namaste! Main AI Assistant hoon.');
    });

    test('CallRecord serialization includes recording metadata and status', () {
      final now = DateTime.now();
      final record = CallRecord(
        id: 'test_123',
        callerName: 'Test Caller',
        callerNumber: '+91 99999 88888',
        timestamp: now,
        duration: const Duration(seconds: 45),
        category: 'Food Delivery',
        status: CallStatus.takenOver,
        keyIntent: 'Parcel delivered to door',
        aiSummary: 'User took over call from AI and received parcel.',
        urgency: 'Low',
        hasRecording: true,
        recordingDuration: const Duration(seconds: 45),
        transcript: [
          TranscriptEntry(speaker: 'ai', text: 'Hello!'),
          TranscriptEntry(speaker: 'caller', text: 'I am here.'),
          TranscriptEntry(speaker: 'user', text: 'Taking over.'),
        ],
      );

      final json = record.toJson();
      expect(json['id'], 'test_123');
      expect(json['status'], 'takenOver');
      expect(json['hasRecording'], true);
      expect(json['recordingDurationSeconds'], 45);
      expect((json['transcript'] as List).length, 3);

      final restored = CallRecord.fromJson(json);
      expect(restored.id, 'test_123');
      expect(restored.status, CallStatus.takenOver);
      expect(restored.hasRecording, true);
      expect(restored.recordingDuration.inSeconds, 45);
      expect(restored.transcript.length, 3);
      expect(restored.transcript.last.speaker, 'user');
    });

    test('All CallStatus enums parse correctly', () {
      for (final status in CallStatus.values) {
        final record = CallRecord(
          id: 'status_test',
          callerName: 'Caller',
          callerNumber: '123',
          timestamp: DateTime.now(),
          duration: const Duration(seconds: 10),
          category: 'General',
          status: status,
          keyIntent: 'Intent',
          aiSummary: 'Summary',
          urgency: 'Low',
          transcript: [],
        );

        final json = record.toJson();
        expect(json['status'], status.name);

        final restored = CallRecord.fromJson(json);
        expect(restored.status, status);
      }
    });
  });
}
