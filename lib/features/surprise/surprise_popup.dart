import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../../ui/pouch.dart';
import '../../ui/riso.dart';
import '../../ui/riso_theme.dart';
import 'link_preview_card.dart';
import 'surprise_media.dart';

/// Shows a received surprise as an opened pouch with its contents rising out
/// of it, growing from [origin] (the tapped pouch or tile, in global
/// coordinates). Marks the surprise as opened.
Future<void> showSurprisePopup(
  BuildContext context, {
  required Surprise surprise,
  required String senderName,
  required AppDependencies dependencies,
  required Rect origin,
  VoidCallback? onOpened,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Riso.ink.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 750),
    pageBuilder: (context, animation, secondaryAnimation) => _SurprisePopup(
      surprise: surprise,
      senderName: senderName,
      dependencies: dependencies,
      animation: animation,
      onOpened: onOpened,
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final grow = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: grow,
        child: child,
        builder: (context, child) {
          final screenCenter = MediaQuery.sizeOf(context).center(Offset.zero);
          final t = grow.value;
          return Opacity(
            opacity: (animation.value * 4).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: (origin.center - screenCenter) * (1 - t),
              child: Transform.scale(
                scale: lerpDouble(0.12, 1, t)!,
                child: child,
              ),
            ),
          );
        },
      );
    },
  );
}

class _SurprisePopup extends StatefulWidget {
  const _SurprisePopup({
    required this.surprise,
    required this.senderName,
    required this.dependencies,
    required this.animation,
    this.onOpened,
  });

  final Surprise surprise;
  final String senderName;
  final AppDependencies dependencies;
  final Animation<double> animation;
  final VoidCallback? onOpened;

  @override
  State<_SurprisePopup> createState() => _SurprisePopupState();
}

class _SurprisePopupState extends State<_SurprisePopup> {
  @override
  void initState() {
    super.initState();
    if (!widget.surprise.isOpened) {
      _markOpened();
    }
  }

  Future<void> _markOpened() async {
    try {
      await widget.dependencies.surprises.markOpened(widget.surprise);
      widget.onOpened?.call();
    } on Object {
      // Best effort: the surprise is already shown; it stays "new" on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width - 24, 460.0);
    final pouchHeight = width * openPouchAspect;
    final cardBottom = width * openPouchCardBottom;
    // Card area hidden inside the pouch; content scrolls clear of it.
    final tucked = cardBottom - width * openPouchMouth;
    final rise = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    final door = widget.surprise.day.day;
    return SafeArea(
      child: Center(
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (media.size.height - media.padding.vertical) * 0.92,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: pouchHeight,
                    child: CustomPaint(
                      painter: OpenPouchPainter(
                        part: OpenPouchPart.back,
                        number: door,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: width * 0.13,
                      right: width * 0.13,
                      bottom: pouchHeight - cardBottom,
                    ),
                    child: ClipRect(
                      clipper: const _OpenTopClipper(),
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.7),
                          end: Offset.zero,
                        ).animate(rise),
                        child: _card(context, bottomPadding: tucked + 6),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: pouchHeight,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: OpenPouchPainter(
                          part: OpenPouchPart.front,
                          number: door,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required double bottomPadding}) {
    final surprise = widget.surprise;
    final theme = Theme.of(context);
    final link = surprise.link;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Riso.paper,
        border: Border.all(color: Riso.ink, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: risoShadow(color: Riso.yellow),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From ${widget.senderName}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Riso.red,
                        ),
                      ),
                      Text(
                        formatAdventDay(surprise.day),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (surprise.hasMedia) ...[
                    SurpriseMediaView(
                      surprise: surprise,
                      repository: widget.dependencies.surprises,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (surprise.note.isNotEmpty) ...[
                    SelectableText(
                      surprise.note,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (link != null)
                    LinkPreviewCard(
                      url: Uri.parse(link),
                      service: widget.dependencies.linkPreviews,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips only the bottom edge, so the card's offset shadow stays visible
/// while the card rises out of the pouch.
class _OpenTopClipper extends CustomClipper<Rect> {
  const _OpenTopClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-24, -24, size.width + 24, size.height);

  @override
  bool shouldReclip(_OpenTopClipper oldClipper) => false;
}
