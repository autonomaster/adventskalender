import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../surprise/load_error.dart';
import '../surprise/surprise_media.dart';
import 'surprise_editor_page.dart';

/// The 24 doors this person fills for their partner.
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
          repository: widget.dependencies.surprises,
          mediaPicker: widget.dependencies.media,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = adventSeasonYear(widget.dependencies.now());
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
        final byDay = {
          for (final surprise in sent)
            if (surprise.day.year == year) surprise.day.day: surprise,
        };
        final theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: adventDoorCount + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '${byDay.length} of $adventDoorCount doors filled. '
                    '$partner sees each surprise on its day.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }
              final door = index;
              final day = adventDate(year, door);
              final surprise = byDay[door];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: surprise == null
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary,
                  foregroundColor: surprise == null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onPrimary,
                  child: Text('$door'),
                ),
                title: Text(formatAdventDay(day)),
                subtitle: Text(
                  surprise == null
                      ? 'Empty – tap to add a surprise'
                      : surpriseSummary(surprise),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: surprise == null
                    ? const Icon(Icons.add)
                    : surprise.isOpened
                    ? Tooltip(
                        message: 'Opened by $partner',
                        child: const Icon(Icons.mark_email_read_outlined),
                      )
                    : const Icon(Icons.check),
                onTap: () => _edit(day, surprise),
              );
            },
          ),
        );
      },
    );
  }
}
