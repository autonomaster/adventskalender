import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../../ui/pouch.dart';
import '../../ui/riso.dart';
import '../../ui/riso_theme.dart';
import '../surprise/load_error.dart';
import '../surprise/surprise_media.dart';
import '../surprise/surprise_popup.dart';

/// Every surprise received so far, newest first, across all years.
class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.dependencies,
    required this.couple,
    required this.onChanged,
  });

  final AppDependencies dependencies;
  final Couple couple;
  final VoidCallback onChanged;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late Future<List<Surprise>> _received;

  @override
  void initState() {
    super.initState();
    _received = _load();
  }

  Future<List<Surprise>> _load() async {
    await widget.dependencies.clock.refresh();
    return widget.dependencies.surprises.receivedBy(widget.couple.me.id);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _received = next;
    });
    await next;
  }

  void _open(BuildContext tileContext, Surprise surprise) {
    final box = tileContext.findRenderObject()! as RenderBox;
    showSurprisePopup(
      context,
      surprise: surprise,
      senderName: widget.couple.partner.displayName,
      dependencies: widget.dependencies,
      origin: box.localToGlobal(Offset.zero) & box.size,
      onOpened: widget.onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.dependencies.clock.now();
    return FutureBuilder<List<Surprise>>(
      future: _received,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LoadError(error: snapshot.error!, onRetry: _reload);
        }
        final received = snapshot.data;
        if (received == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final items =
            received
                .where((surprise) => isDoorUnlocked(surprise.day, now))
                .toList()
              ..sort((a, b) => b.day.compareTo(a.day));
        return RefreshIndicator(
          onRefresh: _reload,
          child: items.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nothing here yet. Surprises appear once their door '
                        'has opened.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _tile(context, items[index]),
                ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Surprise surprise) {
    final theme = Theme.of(context);
    const shadows = [Riso.pink, Riso.yellow, Riso.green, Riso.red];
    return Builder(
      builder: (tileContext) => DecoratedBox(
        decoration: BoxDecoration(
          color: Riso.paper,
          border: Border.all(color: Riso.ink, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: risoShadow(
            color: shadows[surprise.day.day % shadows.length],
            offset: 4,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _open(tileContext, surprise),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: surprise.isOpened
                        ? SurpriseThumbnail(
                            surprise: surprise,
                            repository: widget.dependencies.surprises,
                            linkPreviews: widget.dependencies.linkPreviews,
                          )
                        : ColoredBox(
                            color: Riso.paperShade,
                            child: Center(
                              child: SizedBox(
                                width: 56,
                                height: 56 * pouchAspect,
                                child: CustomPaint(
                                  painter: PouchPainter(
                                    look: PouchLook.sparkling,
                                    number: surprise.day.day,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const Divider(height: 1.5, thickness: 1.5, color: Riso.ink),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Door ${surprise.day.day} · ${surprise.day.year}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        surprise.isOpened
                            ? surpriseSummary(surprise)
                            : 'Not opened yet',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
