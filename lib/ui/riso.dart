import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Risograph inks. Inks are printed with [BlendMode.multiply] so overlapping
/// layers darken like overprinted ink on paper.
abstract final class Riso {
  static const paper = Color(0xFFF4EDE0);
  static const paperShade = Color(0xFFEAE0CE);
  static const green = Color(0xFF00A95C);
  static const red = Color(0xFFF15060);
  static const pink = Color(0xFFFF48B0);
  static const yellow = Color(0xFFFFE14D);
  static const blue = Color(0xFF3255A4);

  /// Text and line ink.
  static const ink = Color(0xFF233467);
}

Paint inkPaint(Color color, {double opacity = 1}) => Paint()
  ..color = color.withValues(alpha: color.a * opacity)
  ..blendMode = BlendMode.multiply
  ..isAntiAlias = true;

/// Uneven ink coverage: scatters paper-coloured specks over [clip].
void paintGrain(
  Canvas canvas,
  Path clip,
  Rect bounds, {
  required int seed,
  double density = 0.03,
  Color color = Riso.paper,
  double size = 1.3,
}) {
  final random = math.Random(seed);
  final count = (bounds.width * bounds.height * density).round();
  final points = Float32List(count * 2);
  for (var i = 0; i < count; i++) {
    points[i * 2] = bounds.left + random.nextDouble() * bounds.width;
    points[i * 2 + 1] = bounds.top + random.nextDouble() * bounds.height;
  }
  canvas
    ..save()
    ..clipPath(clip)
    ..drawRawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = size
        ..strokeCap = StrokeCap.round,
    )
    ..restore();
}

/// Halftone dots on a 45° screen. [intensity] maps a point to 0..1 coverage.
void paintHalftone(
  Canvas canvas,
  Path clip,
  Rect bounds, {
  required Color color,
  required double spacing,
  required double Function(Offset point) intensity,
  double opacity = 1,
}) {
  const buckets = 5;
  final groups = List.generate(buckets, (_) => <double>[]);
  // A 45° screen with dot distance [spacing] is the checkerboard lattice
  // `center + (i, j)·d` with `i + j` even and `d = spacing / √2`.
  final d = spacing * math.sqrt1_2;
  final center = bounds.center;
  final jMin = ((bounds.top - center.dy) / d).ceil();
  final jMax = ((bounds.bottom - center.dy) / d).floor();
  final iMin = ((bounds.left - center.dx) / d).ceil();
  final iMax = ((bounds.right - center.dx) / d).floor();
  for (var j = jMin; j <= jMax; j++) {
    final y = center.dy + j * d;
    for (var i = iMin + (iMin + j).abs() % 2; i <= iMax; i += 2) {
      final point = Offset(center.dx + i * d, y);
      final value = intensity(point).clamp(0.0, 1.0);
      if (value < 0.08) {
        continue;
      }
      final bucket = (value * (buckets - 1)).round();
      groups[bucket]
        ..add(point.dx)
        ..add(point.dy);
    }
  }
  canvas
    ..save()
    ..clipPath(clip);
  for (var bucket = 0; bucket < buckets; bucket++) {
    final coords = groups[bucket];
    if (coords.isEmpty) {
      continue;
    }
    final coverage = (bucket + 1) / buckets;
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.fromList(coords),
      inkPaint(color, opacity: opacity)
        ..strokeWidth = spacing * 0.95 * math.sqrt(coverage)
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.restore();
}

/// Five-pointed star centred on [center].
Path starPath(Offset center, double outer, {double innerRatio = 0.45}) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final radius = i.isEven ? outer : outer * innerRatio;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

/// Four-pointed sparkle.
Path sparklePath(Offset center, double radius) {
  final r = radius;
  final w = radius * 0.22;
  return Path()
    ..moveTo(center.dx, center.dy - r)
    ..quadraticBezierTo(center.dx + w, center.dy - w, center.dx + r, center.dy)
    ..quadraticBezierTo(center.dx + w, center.dy + w, center.dx, center.dy + r)
    ..quadraticBezierTo(center.dx - w, center.dy + w, center.dx - r, center.dy)
    ..quadraticBezierTo(center.dx - w, center.dy - w, center.dx, center.dy - r)
    ..close();
}

/// Draws [path] as dashes.
void drawDashed(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 5,
  double gap = 4,
}) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      canvas.drawPath(
        metric.extractPath(distance, math.min(distance + dash, metric.length)),
        paint,
      );
      distance += dash + gap;
    }
  }
}
