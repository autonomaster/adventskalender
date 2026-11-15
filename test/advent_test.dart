import 'package:flutter_test/flutter_test.dart';

import 'package:adventskalender/core/models/advent.dart';

void main() {
  test('door layout shows each of the 24 doors exactly once', () {
    expect(adventDoorLayout.toSet(), {
      for (var door = 1; door <= adventDoorCount; door++) door,
    });
    expect(adventDoorLayout, hasLength(adventDoorCount));
  });

  test('season shows last December until June, then the upcoming one', () {
    expect(adventSeasonYear(DateTime(2027, 1, 6)), 2026);
    expect(adventSeasonYear(DateTime(2027, 6, 30)), 2026);
    expect(adventSeasonYear(DateTime(2027, 7, 1)), 2027);
    expect(adventSeasonYear(DateTime(2026, 12, 24)), 2026);
  });

  test('a door opens at local midnight of its day', () {
    final door5 = adventDate(2026, 5);
    expect(isDoorUnlocked(door5, DateTime(2026, 12, 4, 23, 59)), isFalse);
    expect(isDoorUnlocked(door5, DateTime(2026, 12, 5)), isTrue);
    expect(isDoorUnlocked(door5, DateTime(2027, 1, 2)), isTrue);
  });

  test('only doors 1 to 24 exist', () {
    expect(() => adventDate(2026, 0), throwsRangeError);
    expect(() => adventDate(2026, 25), throwsRangeError);
  });
}
