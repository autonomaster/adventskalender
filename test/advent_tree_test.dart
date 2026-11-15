import 'package:flutter_test/flutter_test.dart';

import 'package:adventskalender/core/models/advent.dart';
import 'package:adventskalender/ui/advent_tree.dart';
import 'package:adventskalender/ui/pouch.dart';

void main() {
  // Everything in units of the tree width.
  const pouchWidth = pouchWidthFactor;
  const pouchHeight = pouchWidthFactor * pouchAspect;

  test('there is one slot per door', () {
    expect(pouchSlots, hasLength(adventDoorLayout.length));
  });

  test('every pouch hangs from a branch of the tree', () {
    for (final slot in pouchSlots) {
      final hangY = slot.y - pouchHeight / 2 / treeAspect;
      expect(
        slot.x.abs(),
        lessThanOrEqualTo(treeHalfWidthAt(hangY)),
        reason: 'slot $slot hangs in the air',
      );
    }
  });

  test('pouches do not cover each other', () {
    for (var i = 0; i < pouchSlots.length; i++) {
      for (var j = i + 1; j < pouchSlots.length; j++) {
        final a = pouchSlots[i];
        final b = pouchSlots[j];
        final dx = (a.x - b.x).abs();
        final dy = (a.y - b.y).abs() * treeAspect;
        final overlaps = dx < pouchWidth * 0.85 && dy < pouchHeight * 0.85;
        expect(overlaps, isFalse, reason: 'slots $a and $b overlap');
      }
    }
  });
}
