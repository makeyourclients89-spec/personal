import 'package:flutter_test/flutter_test.dart';
import 'package:call_detection_flutter/models/call_record.dart';
import 'package:call_detection_flutter/services/call_store.dart';

void main() {
  group('CallStore Tests', () {
    setUp(() {
      CallStore.instance.resetInitialRecords();
    });

    test('Initial CallStore loads default sample records', () {
      final records = CallStore.instance.records;
      expect(records.length, 2);
      expect(records.first.callerName.contains('Swiggy'), true);
      expect(records.first.hasRecording, true);
    });

    test('addRecord prepends new call record to the list and notifies listeners', () {
      var listenerCalled = false;
      void listener() {
        listenerCalled = true;
      }

      CallStore.instance.addListener(listener);

      final newRecord = CallRecord(
        id: 'new_call_001',
        callerName: 'Direct Test Caller',
        callerNumber: '+91 77777 66666',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 30),
        category: 'Recruitment',
        status: CallStatus.directUser,
        keyIntent: 'Interview test',
        aiSummary: 'Direct call picked within 10s',
        urgency: 'High',
        transcript: [],
        hasRecording: true,
      );

      CallStore.instance.addRecord(newRecord);

      expect(listenerCalled, true);
      expect(CallStore.instance.records.length, 3);
      expect(CallStore.instance.records.first.id, 'new_call_001');
      expect(CallStore.instance.records.first.status, CallStatus.directUser);

      CallStore.instance.removeListener(listener);
    });

    test('clearRecords removes all records', () {
      CallStore.instance.clearRecords();
      expect(CallStore.instance.records.isEmpty, true);
    });
  });
}
