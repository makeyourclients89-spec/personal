import 'package:flutter_test/flutter_test.dart';
import 'package:call_detection_flutter/models/persona.dart';

void main() {
  group('DemoPersona Tests', () {
    test('Preset personas list contains all 5 expected scenarios', () {
      final presets = DemoPersona.presets;
      expect(presets.length, 5);

      final ids = presets.map((p) => p.id).toList();
      expect(ids, containsAll(['delivery', 'telemarketer', 'recruiter', 'spam', 'live_mic']));
    });

    test('Each persona has valid script turns and speakers', () {
      for (final persona in DemoPersona.presets) {
        expect(persona.name.isNotEmpty, true);
        expect(persona.number.isNotEmpty, true);
        expect(persona.category.isNotEmpty, true);
        expect(persona.intent.isNotEmpty, true);
        expect(persona.script.isNotEmpty, true);

        for (final turn in persona.script) {
          expect(turn.text.isNotEmpty, true);
          expect(['ai', 'caller'].contains(turn.speaker), true);
          expect(turn.delay.inMilliseconds, greaterThanOrEqualTo(0));
        }
      }
    });

    test('Live Mic persona has isLiveMic set to true', () {
      final liveMic = DemoPersona.presets.firstWhere((p) => p.id == 'live_mic');
      expect(liveMic.isLiveMic, true);

      final delivery = DemoPersona.presets.firstWhere((p) => p.id == 'delivery');
      expect(delivery.isLiveMic, false);
    });
  });
}
