import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../../ui/advent_tree.dart';
import '../../ui/pouch.dart';
import '../surprise/load_error.dart';
import 'surprise_editor_page.dart';

/// Your partner's tree: the 24 pouches you fill for them.
class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.dependencies,
    required this.couple,
  });

  final AppDependencies dependencies;
  final Couple couple;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  late Future<List<Surprise>> _sent;

  @override
  void initState() {
    super.initState();
    _sent = _load();
  }

  Future<List<Surprise>> _load() =>
      widget.dependencies.surprises.sentBy(widget.couple.me.id);

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _sent = next;
    });
    await next;
  }

  Future<void> _edit(DateTime day, Surprise? existing) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SurpriseEditorPage(
          day: day,
          existing: existing,
          couple: widget.couple,
          dependencies: widget.dependencies,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.dependencies.now();
    final year = adventSeasonYear(now);
    final partner = widget.couple.partner.displayName;
    return FutureBuilder<List<Surprise>>(
      future: _sent,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LoadError(error: snapshot.error!, onRetry: _reload);
        }
        final sent = snapshot.data;
        if (sent == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final byDoor = {
          for (final surprise in sent)
            if (surprise.day.year == year) surprise.day.day: surprise,
        };
        final today = dateOnly(now);

        PouchSpec pouchFor(int door) {
          final surprise = byDoor[door];
          final highlighted = today == adventDate(year, door);
          if (surprise == null) {
            return PouchSpec(
              look: PouchLook.add,
              tooltip: 'Door $door: empty, tap to fill',
              highlighted: highlighted,
            );
          }
          return PouchSpec(
            look: surprise.isOpened ? PouchLook.open : PouchLook.closed,
            tooltip: surprise.isOpened
                ? 'Door $door: opened by $partner'
                : 'Door $door: ready for $partner',
            highlighted: highlighted,
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: TreeScroller(
            headline:
                '${byDoor.length} of $adventDoorCount pouches filled for '
                '$partner. Tap one to fill or change it.',
            tree: AdventTree(
              pouchFor: pouchFor,
              onTap: (door, _) => _edit(adventDate(year, door), byDoor[door]),
            ),
          ),
        );
      },
    );
  }
}
