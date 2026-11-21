import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rasterized_paint.dart';
import 'riso.dart';

/// How a pouch on the tree looks.
enum PouchLook {
  /// Filled and tied shut.
  closed,

  /// Tied shut and not openable yet: printed pale.
  locked,

  /// Filled, ready to open: tied shut with sparkles.
  sparkling,

  /// Already opened.
  open,

  /// Nothing inside yet (dashed outline).
  empty,

  /// Nothing inside yet, and you can fill it (dashed outline with a plus).
  add,
}

/// Pouch boxes are [pouchAspect] times taller than wide.
const double pouchAspect = 1.25;

/// Paints a pouch into a box of `w × w·pouchAspect`.
class PouchPainter extends CustomPainter {
  const PouchPainter({
    required this.look,
    required this.number,
    this.highlighted = false,
  });

  final PouchLook look;
  final int number;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (highlighted) {
      canvas.drawCircle(
        Offset(0.5 * w, 0.78 * w),
        0.6 * w,
        Paint()..color = Riso.yellow,
      );
    }
    switch (look) {
      case PouchLook.closed:
      case PouchLook.sparkling:
        _paintClosed(canvas, w);
        if (look == PouchLook.sparkling) {
          _paintSparkles(canvas, w);
        }
        _paintNumber(canvas, w, Riso.paper, 0.84);
      case PouchLook.locked:
        _paintClosed(canvas, w, opacity: 0.35);
        _paintNumber(canvas, w, Riso.ink, 0.84);
      case PouchLook.open:
        _paintOpen(canvas, w);
        _paintNumber(canvas, w, Riso.paper, 0.9);
      case PouchLook.empty:
      case PouchLook.add:
        _paintOutline(canvas, w, withPlus: look == PouchLook.add);
        _paintNumber(canvas, w, Riso.ink, 0.84);
    }
  }

  static Path closedBody(double w) => Path()
    ..moveTo(0.41 * w, 0.42 * w)
    ..cubicTo(0.30 * w, 0.50 * w, 0.06 * w, 0.66 * w, 0.08 * w, 0.92 * w)
    ..cubicTo(0.10 * w, 1.16 * w, 0.32 * w, 1.22 * w, 0.5 * w, 1.22 * w)
    ..cubicTo(0.68 * w, 1.22 * w, 0.90 * w, 1.16 * w, 0.92 * w, 0.92 * w)
    ..cubicTo(0.94 * w, 0.66 * w, 0.70 * w, 0.50 * w, 0.59 * w, 0.42 * w)
    ..close();

  static Path closedRuffle(double w) {
    final path = Path()
      ..moveTo(0.44 * w, 0.43 * w)
      ..cubicTo(0.38 * w, 0.34 * w, 0.26 * w, 0.27 * w, 0.23 * w, 0.20 * w);
    const bumps = 4;
    for (var i = 0; i < bumps; i++) {
      final x0 = 0.23 + i * 0.54 / bumps;
      final x1 = x0 + 0.54 / bumps;
      path.quadraticBezierTo((x0 + x1) / 2 * w, 0.11 * w, x1 * w, 0.20 * w);
    }
    return path
      ..cubicTo(0.74 * w, 0.27 * w, 0.62 * w, 0.34 * w, 0.56 * w, 0.43 * w)
      ..close();
  }

  void _paintString(Canvas canvas, double w, double toY) {
    canvas.drawLine(
      Offset(0.5 * w, -0.16 * w),
      Offset(0.5 * w, toY * w),
      Paint()
        ..color = Riso.ink
        ..strokeWidth = math.max(1, 0.025 * w),
    );
  }

  void _paintClosed(Canvas canvas, double w, {double opacity = 1}) {
    _paintString(canvas, w, 0.18);
    final body = closedBody(w);
    final ruffle = closedRuffle(w);
    final bounds = Rect.fromLTWH(0, 0, w, w * pouchAspect);
    canvas
      // Knock out the tree's ink so the pouch prints on paper, not on green.
      ..drawPath(body, _knockout)
      ..drawPath(ruffle, _knockout)
      ..drawPath(ruffle, inkPaint(Riso.red, opacity: opacity))
      ..drawPath(body, inkPaint(Riso.red, opacity: opacity));
    paintHalftone(
      canvas,
      body,
      bounds,
      color: Riso.blue,
      spacing: math.max(2.6, 0.075 * w),
      opacity: 0.7 * opacity,
      intensity: (p) => (p.dx / w - 0.55) * 1.6 + (p.dy / w - 0.9) * 0.6,
    );
    paintGrain(
      canvas,
      Path.combine(PathOperation.union, body, ruffle),
      bounds,
      seed: number,
      density: 0.06,
      size: math.max(0.8, 0.02 * w),
    );
    _paintBow(canvas, Offset(0.5 * w, 0.43 * w), w);
  }

  void _paintSparkles(Canvas canvas, double w) {
    final fill = Paint()..color = Riso.yellow;
    final outline = Paint()
      ..color = Riso.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 0.018 * w);
    for (final (x, y, r) in const [
      (0.04, 0.30, 0.17),
      (0.97, 0.60, 0.14),
      (0.88, 0.12, 0.10),
      (0.08, 1.08, 0.10),
    ]) {
      final sparkle = sparklePath(Offset(x * w, y * w), r * w);
      canvas
        ..drawPath(sparkle, fill)
        ..drawPath(sparkle, outline);
    }
  }

  void _paintOpen(Canvas canvas, double w) {
    _paintString(canvas, w, 0.27);
    final geometry = OpenPouchGeometry(
      width: w,
      mouthY: 0.36 * w,
      rx: 0.31 * w,
      ry: 0.08 * w,
      bottom: 1.22 * w,
      bulge: 0.06 * w,
    );
    final bounds = Rect.fromLTWH(0, 0, w, w * pouchAspect);
    geometry.paintBack(canvas, bounds, seed: number);
    geometry.paintFront(canvas, bounds, seed: number, bodyOpacity: 0.85);
    final tie = Path()
      ..moveTo(0.14 * w, 0.62 * w)
      ..quadraticBezierTo(0.5 * w, 0.74 * w, 0.86 * w, 0.62 * w);
    canvas.drawPath(
      tie,
      inkPaint(Riso.blue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, 0.03 * w),
    );
  }

  void _paintOutline(Canvas canvas, double w, {required bool withPlus}) {
    _paintString(canvas, w, 0.18);
    final silhouette = Path.combine(
      PathOperation.union,
      closedBody(w),
      closedRuffle(w),
    );
    canvas.drawPath(silhouette, _knockout);
    drawDashed(
      canvas,
      silhouette,
      Paint()
        ..color = Riso.ink.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, 0.03 * w),
      dash: math.max(2.5, 0.08 * w),
      gap: math.max(2, 0.06 * w),
    );
    if (withPlus) {
      final center = Offset(0.82 * w, 1.1 * w);
      canvas.drawCircle(center, 0.15 * w, Paint()..color = Riso.yellow);
      final plus = Paint()
        ..color = Riso.ink
        ..strokeWidth = math.max(1.2, 0.035 * w)
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(
          center - Offset(0.07 * w, 0),
          center + Offset(0.07 * w, 0),
          plus,
        )
        ..drawLine(
          center - Offset(0, 0.07 * w),
          center + Offset(0, 0.07 * w),
          plus,
        );
    }
  }

  void _paintNumber(Canvas canvas, double w, Color color, double centerY) {
    final text = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: color,
          fontSize: 0.36 * w,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(0.5 * w - text.width / 2, centerY * w - text.height / 2),
    );
  }

  @override
  bool shouldRepaint(PouchPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.number != number ||
      oldDelegate.highlighted != highlighted;
}

/// An opened pouch, split into the part behind its contents ([paintBack]) and
/// the part in front ([paintFront]) so contents can stick out of the mouth.
class OpenPouchGeometry {
  const OpenPouchGeometry({
    required this.width,
    required this.mouthY,
    required this.rx,
    required this.ry,
    required this.bottom,
    required this.bulge,
  });

  final double width;
  final double mouthY;
  final double rx;
  final double ry;
  final double bottom;
  final double bulge;

  double get cx => width / 2;
  Rect get mouth => Rect.fromCenter(
    center: Offset(cx, mouthY),
    width: rx * 2,
    height: ry * 2,
  );

  Path get body {
    final w = width;
    final belly = mouthY + (bottom - mouthY) * 0.55;
    return Path()
      ..moveTo(cx - rx, mouthY)
      ..cubicTo(
        cx - rx - bulge,
        mouthY + (belly - mouthY) * 0.5,
        0.02 * w,
        belly - (belly - mouthY) * 0.2,
        0.06 * w,
        belly,
      )
      ..cubicTo(0.09 * w, bottom - 0.02 * w, 0.30 * w, bottom, cx, bottom)
      ..cubicTo(0.70 * w, bottom, 0.91 * w, bottom - 0.02 * w, 0.94 * w, belly)
      ..cubicTo(
        0.98 * w,
        belly - (belly - mouthY) * 0.2,
        cx + rx + bulge,
        mouthY + (belly - mouthY) * 0.5,
        cx + rx,
        mouthY,
      )
      ..arcTo(mouth, 0, math.pi, false)
      ..close();
  }

  /// Scalloped band of fabric folded outwards around the rim.
  Path _fold({required bool upper}) {
    final grow = ry * 0.9;
    final outer = Rect.fromCenter(
      center: Offset(cx, mouthY + (upper ? -grow * 0.15 : grow * 0.25)),
      width: (rx + width * 0.025) * 2,
      height: (ry + grow) * 2,
    );
    final path = Path()..moveTo(cx + (upper ? -rx : rx), mouthY);
    path.arcTo(mouth, upper ? math.pi : 0, math.pi, false);
    // Back along the outer edge with scallops.
    const bumps = 7;
    final start = upper ? 0.0 : math.pi;
    const sweep = -math.pi;
    Offset at(Rect rect, double angle, double scale) {
      final r = rect.center;
      return Offset(
        r.dx + math.cos(angle) * rect.width / 2 * scale,
        r.dy + math.sin(angle) * rect.height / 2 * scale,
      );
    }

    final first = at(outer, start, 1);
    path.lineTo(first.dx, first.dy);
    for (var i = 0; i < bumps; i++) {
      final a0 = start + sweep * i / bumps;
      final a1 = start + sweep * (i + 1) / bumps;
      final control = at(outer, (a0 + a1) / 2, 1.12);
      final end = at(outer, a1, 1);
      path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    }
    return path..close();
  }

  void paintBack(Canvas canvas, Rect bounds, {required int seed}) {
    final fold = _fold(upper: true);
    canvas
      ..drawPath(fold, _knockout)
      ..drawOval(mouth, _knockout)
      ..drawPath(fold, inkPaint(Riso.pink, opacity: 0.85))
      ..drawOval(mouth, inkPaint(Riso.red))
      ..drawOval(mouth, inkPaint(Riso.blue, opacity: 0.85));
    paintGrain(canvas, fold, bounds, seed: seed + 1, density: 0.05);
  }

  void paintFront(
    Canvas canvas,
    Rect bounds, {
    required int seed,
    double bodyOpacity = 1,
  }) {
    final body = this.body;
    final fold = _fold(upper: false);
    canvas
      ..drawPath(body, _knockout)
      ..drawPath(fold, _knockout)
      ..drawPath(body, inkPaint(Riso.red, opacity: bodyOpacity));
    paintHalftone(
      canvas,
      body,
      bounds,
      color: Riso.blue,
      spacing: math.max(2.6, math.min(9, 0.03 * width + 1.5)),
      opacity: 0.7,
      intensity: (p) => (p.dx - cx) / rx * 0.7 - 0.15,
    );
    canvas.drawPath(fold, inkPaint(Riso.pink, opacity: 0.9));
    paintGrain(
      canvas,
      Path.combine(PathOperation.union, body, fold),
      bounds,
      seed: seed,
      density: 0.05,
      size: math.min(1.6, math.max(0.8, 0.02 * width)),
    );
  }
}

/// The large opened pouch at the bottom of the surprise popup.
/// Box is `w × w·openPouchAspect`.
const double openPouchAspect = 0.62;

/// Where, as a fraction of the width, the popup card ends inside the pouch.
const double openPouchCardBottom = 0.17;

/// Where the mouth of the large pouch sits, as a fraction of the width.
const double openPouchMouth = 0.11;

enum OpenPouchPart { back, front }

class OpenPouchPainter extends CustomPainter {
  const OpenPouchPainter({required this.part, required this.number});

  final OpenPouchPart part;
  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final geometry = OpenPouchGeometry(
      width: w,
      mouthY: openPouchMouth * w,
      rx: 0.41 * w,
      ry: 0.05 * w,
      bottom: 0.61 * w,
      bulge: 0.05 * w,
    );
    final bounds = Offset.zero & size;
    if (part == OpenPouchPart.back) {
      geometry.paintBack(canvas, bounds, seed: number);
      return;
    }
    geometry.paintFront(canvas, bounds, seed: number);
    final tie = Path()
      ..moveTo(0.04 * w, 0.27 * w)
      ..quadraticBezierTo(0.5 * w, 0.36 * w, 0.96 * w, 0.27 * w);
    canvas
      ..save()
      ..clipPath(geometry.body)
      ..drawPath(
        tie,
        inkPaint(Riso.blue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.014 * w,
      )
      ..restore();
    _paintBow(canvas, Offset(0.5 * w, 0.315 * w), 0.4 * w);
    final text = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Riso.paper,
          fontSize: 0.12 * w,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(0.5 * w - text.width / 2, 0.47 * w - text.height / 2),
    );
  }

  @override
  bool shouldRepaint(OpenPouchPainter oldDelegate) =>
      oldDelegate.part != part || oldDelegate.number != number;
}

/// A tappable pouch hanging on the tree.
class PouchButton extends StatefulWidget {
  const PouchButton({
    super.key,
    required this.number,
    required this.look,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
    this.tilt = 0,
  });

  final int number;
  final PouchLook look;
  final String tooltip;
  final bool highlighted;

  /// Resting rotation in radians, so pouches don't hang in a strict grid.
  final double tilt;

  /// Called with the pouch's global rectangle.
  final ValueChanged<Rect> onTap;

  @override
  State<PouchButton> createState() => _PouchButtonState();
}

class _PouchButtonState extends State<PouchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateWiggle();
  }

  @override
  void didUpdateWidget(PouchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateWiggle();
  }

  void _updateWiggle() {
    final animate =
        widget.look == PouchLook.sparkling &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_wiggle.isAnimating) {
      _wiggle.repeat(reverse: true);
    } else if (!animate && _wiggle.isAnimating) {
      _wiggle
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _tap() {
    final box = context.findRenderObject()! as RenderBox;
    widget.onTap(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _tap,
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedBuilder(
              animation: _wiggle,
              builder: (context, child) => Transform.rotate(
                // Swing around the hanging point at the top.
                alignment: Alignment.topCenter,
                angle:
                    widget.tilt +
                    (_wiggle.isAnimating ? (_wiggle.value - 0.5) * 0.22 : 0),
                child: child,
              ),
              child: RasterizedPaint(
                // Strings, sparkles and the highlight reach outside the box.
                overflow: 0.25,
                painter: PouchPainter(
                  look: widget.look,
                  number: widget.number,
                  highlighted: widget.highlighted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tied bow; [s] is the bow's reference size.
void _paintBow(Canvas canvas, Offset knot, double s) {
  // Printed slightly off-register, like a second ink pass.
  final k = knot + Offset(0.03 * s, 0.02 * s);
  final stroke = inkPaint(Riso.blue)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, 0.04 * s)
    ..strokeCap = StrokeCap.round;
  final bow = Path()
    ..moveTo(k.dx, k.dy)
    ..cubicTo(
      k.dx - 0.16 * s,
      k.dy - 0.12 * s,
      k.dx - 0.22 * s,
      k.dy + 0.06 * s,
      k.dx,
      k.dy,
    )
    ..cubicTo(
      k.dx + 0.16 * s,
      k.dy - 0.12 * s,
      k.dx + 0.22 * s,
      k.dy + 0.06 * s,
      k.dx,
      k.dy,
    )
    ..moveTo(k.dx, k.dy)
    ..quadraticBezierTo(
      k.dx - 0.05 * s,
      k.dy + 0.10 * s,
      k.dx - 0.10 * s,
      k.dy + 0.17 * s,
    )
    ..moveTo(k.dx, k.dy)
    ..quadraticBezierTo(
      k.dx + 0.06 * s,
      k.dy + 0.09 * s,
      k.dx + 0.11 * s,
      k.dy + 0.15 * s,
    );
  canvas
    ..drawPath(bow, stroke)
    ..drawCircle(k, math.max(1.2, 0.035 * s), inkPaint(Riso.blue));
}

final Paint _knockout = Paint()..color = Riso.paper;
