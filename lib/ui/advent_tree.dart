import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models/advent.dart';
import 'pouch.dart';
import 'rasterized_paint.dart';
import 'riso.dart';

/// The tree box is [treeAspect] times taller than wide.
const double treeAspect = 1.5;

/// Pouch width as a fraction of the tree width.
const double pouchWidthFactor = 0.115;

/// A pouch position on the tree. [x] is the offset from the trunk axis as a
/// fraction of the tree width, [y] the pouch centre as a fraction of the tree
/// height, [tilt] its resting rotation in radians.
typedef PouchSlot = ({double x, double y, double tilt});

/// Hand-placed so the pouches look scattered rather than gridded. Slot `i`
/// holds door `adventDoorLayout[i]`; the topmost slot holds door 24. Every
/// pouch's hanging point (top centre) is on a branch.
const List<PouchSlot> pouchSlots = [
  (x: 0.000, y: 0.200, tilt: 0.04),
  (x: -0.085, y: 0.290, tilt: -0.08),
  (x: 0.070, y: 0.296, tilt: 0.06),
  (x: -0.145, y: 0.386, tilt: 0.05),
  (x: 0.000, y: 0.380, tilt: -0.05),
  (x: 0.150, y: 0.386, tilt: 0.09),
  (x: -0.235, y: 0.474, tilt: -0.07),
  (x: -0.085, y: 0.469, tilt: 0.03),
  (x: 0.070, y: 0.477, tilt: -0.04),
  (x: 0.220, y: 0.474, tilt: 0.08),
  (x: -0.190, y: 0.566, tilt: 0.06),
  (x: -0.035, y: 0.562, tilt: -0.09),
  (x: 0.120, y: 0.569, tilt: 0.02),
  (x: 0.255, y: 0.563, tilt: -0.05),
  (x: -0.200, y: 0.657, tilt: 0.07),
  (x: -0.045, y: 0.652, tilt: -0.04),
  (x: 0.110, y: 0.659, tilt: 0.07),
  (x: -0.305, y: 0.750, tilt: -0.06),
  (x: -0.130, y: 0.745, tilt: 0.04),
  (x: 0.050, y: 0.752, tilt: -0.08),
  (x: 0.235, y: 0.747, tilt: 0.05),
  (x: -0.225, y: 0.843, tilt: -0.03),
  (x: 0.020, y: 0.839, tilt: 0.08),
  (x: 0.255, y: 0.846, tilt: -0.06),
];

/// Half-width of the tree silhouette at height [y] (fraction of tree height),
/// as a fraction of the tree width. Zero above the top and below the skirt.
double treeHalfWidthAt(double y) {
  if (y < _tiers.first.apex || y > _tiers.last.bottom) {
    return 0;
  }
  var halfWidth = 0.0;
  for (final tier in _tiers) {
    if (y >= tier.apex && y <= tier.bottom) {
      final t = (y - tier.apex) / (tier.bottom - tier.apex);
      halfWidth = math.max(halfWidth, tier.halfWidth * t);
    }
  }
  return halfWidth;
}

typedef _Tier = ({double apex, double bottom, double halfWidth});

const List<_Tier> _tiers = [
  (apex: 0.085, bottom: 0.275, halfWidth: 0.20),
  (apex: 0.180, bottom: 0.430, halfWidth: 0.28),
  (apex: 0.300, bottom: 0.590, halfWidth: 0.36),
  (apex: 0.440, bottom: 0.750, halfWidth: 0.43),
  (apex: 0.580, bottom: 0.905, halfWidth: 0.49),
];

/// What a pouch on the tree should show.
class PouchSpec {
  const PouchSpec({
    required this.look,
    required this.tooltip,
    this.highlighted = false,
  });

  final PouchLook look;
  final String tooltip;
  final bool highlighted;
}

/// The riso-printed tree with all 24 pouches.
class AdventTree extends StatelessWidget {
  const AdventTree({
    super.key,
    required this.pouchFor,
    required this.onTap,
    this.maxWidth = 520,
  });

  final PouchSpec Function(int door) pouchFor;

  /// Called with the door number and the pouch's global rectangle.
  final void Function(int door, Rect rect) onTap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = math.min(constraints.maxWidth, maxWidth);
        if (constraints.hasBoundedHeight) {
          width = math.min(width, constraints.maxHeight / treeAspect);
        }
        final height = width * treeAspect;
        final pouchWidth = width * pouchWidthFactor;
        final pouchHeight = pouchWidth * pouchAspect;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: RasterizedPaint(painter: TreePainter()),
                ),
                for (var i = 0; i < pouchSlots.length; i++)
                  _pouch(
                    adventDoorLayout[i],
                    pouchSlots[i],
                    width,
                    height,
                    pouchWidth,
                    pouchHeight,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pouch(
    int door,
    PouchSlot slot,
    double width,
    double height,
    double pouchWidth,
    double pouchHeight,
  ) {
    final spec = pouchFor(door);
    return Positioned(
      left: width / 2 + slot.x * width - pouchWidth / 2,
      top: slot.y * height - pouchHeight / 2,
      width: pouchWidth,
      height: pouchHeight,
      child: PouchButton(
        key: ValueKey('door-$door'),
        number: door,
        look: spec.look,
        tooltip: spec.tooltip,
        highlighted: spec.highlighted,
        tilt: slot.tilt,
        onTap: (rect) => onTap(door, rect),
      ),
    );
  }
}

/// Plain fir with a star on top, printed in green, blue, red and yellow.
class TreePainter extends CustomPainter {
  const TreePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    final cx = w / 2;
    final random = math.Random(1224);

    // Ground shadow and trunk (red over green prints brown).
    final ground = Rect.fromCenter(
      center: Offset(cx, 0.965 * h),
      width: 0.62 * w,
      height: 0.035 * h,
    );
    paintHalftone(
      canvas,
      Path()..addOval(ground),
      ground.inflate(4),
      color: Riso.blue,
      spacing: math.max(3, 0.012 * w),
      opacity: 0.8,
      intensity: (p) => 1 - ((p.dx - cx).abs() / (ground.width / 2)) * 0.9,
    );
    final trunk = Rect.fromLTRB(
      cx - 0.05 * w,
      0.875 * h,
      cx + 0.05 * w,
      0.965 * h,
    );
    canvas
      ..drawRect(trunk, inkPaint(Riso.red))
      ..drawRect(
        trunk.shift(Offset(0.012 * w, 0.004 * h)),
        inkPaint(Riso.green, opacity: 0.85),
      );

    // Needles.
    final tiers = [for (final tier in _tiers) _tierPath(size, tier, random)];
    var silhouette = tiers.first;
    for (final tier in tiers.skip(1)) {
      silhouette = Path.combine(PathOperation.union, silhouette, tier);
    }
    canvas.drawPath(silhouette, inkPaint(Riso.green));

    // Blue pass, slightly off register: shadows under each tier and on the
    // right-hand side.
    final registration = Offset(0.004 * w, -0.002 * h);
    canvas
      ..save()
      ..translate(registration.dx, registration.dy);
    var shadows = Path();
    for (var i = 0; i < tiers.length - 1; i++) {
      final cast = tiers[i].shift(Offset(0.01 * w, 0.03 * h));
      shadows = Path.combine(
        PathOperation.union,
        shadows,
        Path.combine(
          PathOperation.difference,
          Path.combine(PathOperation.intersect, cast, silhouette),
          tiers[i],
        ),
      );
    }
    final spacing = math.max(3.2, 0.014 * w);
    paintHalftone(
      canvas,
      shadows,
      bounds,
      color: Riso.blue,
      spacing: spacing,
      opacity: 0.85,
      intensity: (_) => 0.75,
    );
    paintHalftone(
      canvas,
      silhouette,
      bounds,
      color: Riso.blue,
      spacing: spacing,
      opacity: 0.7,
      intensity: (p) => (p.dx - cx) / (0.45 * w) * 0.7 - 0.05,
    );
    canvas.restore();

    paintGrain(
      canvas,
      silhouette,
      bounds,
      seed: 7,
      density: 0.045,
      size: math.max(1, 0.003 * w),
    );

    _paintStar(canvas, Offset(cx, 0.062 * h), 0.075 * w);
  }

  Path _tierPath(Size size, _Tier tier, math.Random random) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final apex = Offset(cx, tier.apex * h);
    final halfWidth = tier.halfWidth * w;
    final bottom = tier.bottom * h;
    final lift = 0.028 * h;
    final needle = 0.016 * h;
    final right = Offset(cx + halfWidth, bottom + needle * 0.4);
    final left = Offset(cx - halfWidth, bottom + needle * 0.4);

    double edgeY(double x) {
      final t = (x - cx) / halfWidth;
      return bottom - lift * (1 - t * t);
    }

    final path = Path()..moveTo(apex.dx, apex.dy);
    // Right flank: small needle clusters pointing outwards and down.
    _flank(path, apex, right, outwards: 1, needle: needle, random: random);
    // Skirt, right to left, with needle tips hanging down.
    final tips = math.max(6, (2 * halfWidth / (0.032 * w)).round());
    for (var i = 1; i <= tips; i++) {
      final x0 = right.dx - (i - 1) * 2 * halfWidth / tips;
      final x1 = right.dx - i * 2 * halfWidth / tips;
      final mid = (x0 + x1) / 2;
      final length = needle * (0.7 + random.nextDouble() * 0.6);
      path
        ..lineTo(mid, edgeY(mid) + length)
        ..lineTo(x1, edgeY(x1) - needle * 0.35);
    }
    path.lineTo(left.dx, left.dy);
    // Left flank back up to the apex.
    _flank(path, left, apex, outwards: -1, needle: needle, random: random);
    return path..close();
  }

  void _flank(
    Path path,
    Offset from,
    Offset to, {
    required double outwards,
    required double needle,
    required math.Random random,
  }) {
    const clusters = 4;
    for (var i = 1; i <= clusters; i++) {
      final a = Offset.lerp(from, to, (i - 0.5) / clusters)!;
      final b = Offset.lerp(from, to, i / clusters)!;
      final length = needle * (0.6 + random.nextDouble() * 0.6);
      path
        ..lineTo(a.dx + outwards * length, a.dy + length * 0.8)
        ..lineTo(b.dx - outwards * needle * 0.15, b.dy);
    }
  }

  void _paintStar(Canvas canvas, Offset center, double radius) {
    final rays = Paint()
      ..color = Riso.yellow
      ..strokeWidth = math.max(1.5, radius * 0.07)
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.multiply;
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + (i + 0.5) * math.pi / 5;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final length = i.isEven ? 0.55 : 0.35;
      canvas.drawLine(
        center + direction * radius * 1.15,
        center + direction * radius * (1.15 + length),
        rays,
      );
    }
    canvas
      ..drawPath(
        starPath(center + Offset(radius * 0.09, radius * 0.07), radius),
        inkPaint(Riso.pink, opacity: 0.9),
      )
      ..drawPath(starPath(center, radius), inkPaint(Riso.yellow));
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) => false;
}

/// Headline plus a tree that fills the remaining height on tall screens and
/// scrolls on short ones.
class TreeScroller extends StatelessWidget {
  const TreeScroller({super.key, required this.headline, required this.tree});

  final String headline;
  final Widget tree;

  /// Narrowest tree before the page scrolls instead of shrinking it.
  static const _minTreeWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const headerHeight = 52.0;
        final available = constraints.maxHeight - headerHeight - 16;
        final width = math.min(
          constraints.maxWidth,
          math.max(_minTreeWidth, available / treeAspect),
        );
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    headline,
                    maxLines: 2,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: width * treeAspect, child: tree),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
