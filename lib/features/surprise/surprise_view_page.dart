import 'package:flutter/material.dart';

import '../../core/data/surprise_repository.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import 'surprise_media.dart';

/// Shows one received surprise and marks it as opened.
class SurpriseViewPage extends StatefulWidget {
  const SurpriseViewPage({
    super.key,
    required this.surprise,
    required this.senderName,
    required this.repository,
    this.onOpened,
  });

  final Surprise surprise;
  final String senderName;
  final SurpriseRepository repository;
  final VoidCallback? onOpened;

  @override
  State<SurpriseViewPage> createState() => _SurpriseViewPageState();
}

class _SurpriseViewPageState extends State<SurpriseViewPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.surprise.isOpened) {
      _markOpened();
    }
  }

  Future<void> _markOpened() async {
    try {
      await widget.repository.markOpened(widget.surprise);
      widget.onOpened?.call();
    } on Object {
      // Best effort: the surprise is already shown; it stays "new" on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final surprise = widget.surprise;
    final theme = Theme.of(context);
    final link = surprise.link;
    return Scaffold(
      appBar: AppBar(title: Text('Door ${surprise.day.day}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'From ${widget.senderName}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text(formatAdventDay(surprise.day), style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          if (surprise.hasMedia) ...[
            SurpriseMediaView(
              surprise: surprise,
              repository: widget.repository,
            ),
            const SizedBox(height: 20),
          ],
          if (surprise.note.isNotEmpty) ...[
            SelectableText(surprise.note, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
          ],
          if (link != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text(link, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openExternal(context, Uri.parse(link)),
              ),
            ),
        ],
      ),
    );
  }
}
