import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/domain/settings.dart';

void main() {
  test(
    'opacity values from older or invalid saves stay within slider range',
    () {
      final older = GameSettings.fromJson({});
      expect(older.backgroundOpacity, 1);
      expect(older.roadOpacity, 1);
      expect(older.overallOpacity, 1);
      final settings = GameSettings.fromJson({
        'backgroundOpacity': -1,
        'roadOpacity': 2,
        'overallOpacity': double.nan,
      });
      expect(settings.backgroundOpacity, 0);
      expect(settings.roadOpacity, 1);
      expect(settings.overallOpacity, 1);
      expect(
        GameSettings.fromJson({'overallOpacity': 'invalid'}).overallOpacity,
        1,
      );
    },
  );
}
