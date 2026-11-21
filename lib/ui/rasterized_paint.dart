import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Paints [painter] once into a bitmap and shows that bitmap.
///
/// The riso art consists of tens of thousands of halftone dots and grain
/// specks. Neither Impeller (Android, iOS) nor the web renderers keep a raster
/// cache, so as a plain [CustomPaint] the whole tree would be re-rasterized on
/// every animation frame (wiggling pouches, the popup transition). As a bitmap
/// each frame only composites a few images.
class RasterizedPaint extends StatefulWidget {
  const RasterizedPaint({super.key, required this.painter, this.overflow = 0});

  final CustomPainter painter;

  /// How far, as a fraction of the widget's width, the painting reaches
  /// outside the widget's box on every side.
  final double overflow;

  @override
  State<RasterizedPaint> createState() => _RasterizedPaintState();
}

class _RasterizedPaintState extends State<RasterizedPaint> {
  ui.Image? _image;
  Size? _size;
  double? _pixelRatio;
  CustomPainter? _painted;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _rasterize(Size size, double pixelRatio, double margin) {
    final width = ((size.width + 2 * margin) * pixelRatio).ceil();
    final height = ((size.height + 2 * margin) * pixelRatio).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(margin, margin);
    widget.painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(math.max(1, width), math.max(1, height));
    picture.dispose();
    _image?.dispose();
    _image = image;
    _size = size;
    _pixelRatio = pixelRatio;
    _painted = widget.painter;
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty || !size.isFinite) {
          return const SizedBox.shrink();
        }
        final margin = widget.overflow * size.width;
        final painted = _painted;
        if (_image == null ||
            size != _size ||
            pixelRatio != _pixelRatio ||
            painted == null ||
            (!identical(painted, widget.painter) &&
                widget.painter.shouldRepaint(painted))) {
          _rasterize(size, pixelRatio, margin);
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -margin,
              top: -margin,
              width: size.width + 2 * margin,
              height: size.height + 2 * margin,
              child: RawImage(
                image: _image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        );
      },
    );
  }
}
