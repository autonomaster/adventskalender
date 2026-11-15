import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../surprise/load_error.dart';
import '../surprise/surprise_view_page.dart';

const _pine = Color(0xFF1F4D3A);
const _gold = Color(0xFFE8C872);

enum _DoorState { locked, waiting, fresh, opened }

/// The 24 doors with surprises from the partner.
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

  Future<List<Surprise>> _load() =>
      widget.dependencies.surprises.receivedBy(widget.couple.me.id);

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _received = next;
    });
    await next;
  }

  void _tapDoor(int door, _DoorState state, Surprise? surprise) {
    final partner = widget.couple.partner.displayName;
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case _DoorState.locked:
        messenger.showSnackBar(
          SnackBar(content: Text('Door $door opens on $door December.')),
        );
      case _DoorState.waiting:
        messenger.showSnackBar(
          SnackBar(content: Text('$partner has not filled door $door yet.')),
        );
      case _DoorState.fresh:
      case _DoorState.opened:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SurpriseViewPage(
              surprise: surprise!,
              senderName: partner,
              repository: widget.dependencies.surprises,
              onOpened: widget.onChanged,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.dependencies.now();
    final year = adventSeasonYear(now);
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
        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    _headline(now, year),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverGrid.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.8,
                  children: [
                    for (final door in adventDoorLayout)
                      _buildDoor(door, adventDate(year, door), now, byDoor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDoor(
    int door,
    DateTime day,
    DateTime now,
    Map<int, Surprise> byDoor,
  ) {
    final surprise = byDoor[door];
    final state = !isDoorUnlocked(day, now)
        ? _DoorState.locked
        : surprise == null
        ? _DoorState.waiting
        : surprise.isOpened
        ? _DoorState.opened
        : _DoorState.fresh;
    return _Door(
      key: ValueKey('door-$door'),
      door: door,
      state: state,
      isToday: dateOnly(now) == day,
      onTap: () => _tapDoor(door, state, surprise),
    );
  }

  String _headline(DateTime now, int year) {
    final today = dateOnly(now);
    final first = adventDate(year, 1);
    if (today.isBefore(first)) {
      final days = first.difference(today).inDays;
      return 'From ${widget.couple.partner.displayName}. '
          'The first door opens in $days ${days == 1 ? 'day' : 'days'}.';
    }
    if (today.isAfter(adventDate(year, adventDoorCount))) {
      return 'Frohe Weihnachten! All doors are open.';
    }
    return 'Door ${today.day} is open today.';
  }
}

class _Door extends StatelessWidget {
  const _Door({
    super.key,
    required this.door,
    required this.state,
    required this.isToday,
    required this.onTap,
  });

  final int door;
  final _DoorState state;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (state) {
      _DoorState.locked => (_pine, _gold, null),
      _DoorState.waiting => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.hourglass_empty,
      ),
      _DoorState.fresh => (scheme.primary, _gold, Icons.card_giftcard),
      _DoorState.opened => (
        scheme.surface,
        scheme.primary,
        Icons.favorite_border,
      ),
    };
    return Semantics(
      button: true,
      label: 'Door $door',
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isToday
              ? const BorderSide(color: _gold, width: 3)
              : BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$door',
                style: TextStyle(
                  color: foreground,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (icon != null) Icon(icon, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
