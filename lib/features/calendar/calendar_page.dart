import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../../ui/advent_tree.dart';
import '../../ui/pouch.dart';
import '../surprise/load_error.dart';
import '../surprise/surprise_popup.dart';

/// Your tree: the pouches your partner filled for you.
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.dependencies,
    required this.couple,
    required this.onChanged,
  });

  final AppDependencies dependencies;
  final Couple couple;
  final VoidCallback onChanged;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
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

  @override
  Widget build(BuildContext context) {
    final now = widget.dependencies.clock.now();
    final year = adventSeasonYear(now);
    final partner = widget.couple.partner.displayName;
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
        final byDoor = {
          for (final surprise in received)
            if (surprise.day.year == year && isDoorUnlocked(surprise.day, now))
              surprise.day.day: surprise,
        };
        final today = dateOnly(now);

        PouchSpec pouchFor(int door) {
          final day = adventDate(year, door);
          final surprise = byDoor[door];
          final highlighted = today == day;
          if (!isDoorUnlocked(day, now)) {
            return PouchSpec(
              look: PouchLook.locked,
              tooltip: 'Door $door opens on $door December',
              highlighted: highlighted,
            );
          }
          if (surprise == null) {
            return PouchSpec(
              look: PouchLook.empty,
              tooltip: 'Door $door: $partner has not filled it yet',
              highlighted: highlighted,
            );
          }
          return PouchSpec(
            look: surprise.isOpened ? PouchLook.open : PouchLook.sparkling,
            tooltip: surprise.isOpened
                ? 'Door $door: opened'
                : 'Door $door: ready to open',
            highlighted: highlighted,
          );
        }

        void onTap(int door, Rect rect) {
          final day = adventDate(year, door);
          final surprise = byDoor[door];
          final messenger = ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar();
          if (!isDoorUnlocked(day, now)) {
            messenger.showSnackBar(
              SnackBar(content: Text('Door $door opens on $door December.')),
            );
          } else if (surprise == null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('$partner has not filled door $door yet.'),
              ),
            );
          } else {
            showSurprisePopup(
              context,
              surprise: surprise,
              senderName: partner,
              dependencies: widget.dependencies,
              origin: rect,
              onOpened: widget.onChanged,
            );
          }
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: TreeScroller(
            headline: _headline(now, year),
            tree: AdventTree(pouchFor: pouchFor, onTap: onTap),
          ),
        );
      },
    );
  }

  String _headline(DateTime now, int year) {
    final today = dateOnly(now);
    final first = adventDate(year, 1);
    if (today.isBefore(first)) {
      final days = first.difference(today).inDays;
      return 'Filled by ${widget.couple.partner.displayName}. The first pouch '
          'opens in $days ${days == 1 ? 'day' : 'days'}.';
    }
    if (today.isAfter(adventDate(year, adventDoorCount))) {
      return 'Frohe Weihnachten! All pouches are open.';
    }
    return 'Filled by ${widget.couple.partner.displayName}. '
        'Pouch ${today.day} is ready today.';
  }
}
