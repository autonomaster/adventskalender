import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../surprise/load_error.dart';
import '../surprise/surprise_media.dart';
import '../surprise/surprise_view_page.dart';

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

  Future<List<Surprise>> _load() =>
      widget.dependencies.surprises.receivedBy(widget.couple.me.id);

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _received = next;
    });
    await next;
  }

  void _open(Surprise surprise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SurpriseViewPage(
          surprise: surprise,
          senderName: widget.couple.partner.displayName,
          repository: widget.dependencies.surprises,
          onOpened: widget.onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.dependencies.now();
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(surprise),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: surprise.isOpened
                  ? SurpriseThumbnail(
                      surprise: surprise,
                      repository: widget.dependencies.surprises,
                    )
                  : ColoredBox(
                      color: theme.colorScheme.primary,
                      child: const Center(
                        child: Icon(
                          Icons.card_giftcard,
                          size: 48,
                          color: Color(0xFFE8C872),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Door ${surprise.day.day} · ${surprise.day.year}',
                    style: theme.textTheme.titleSmall,
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
    );
  }
}
