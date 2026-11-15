import 'package:flutter/material.dart';

import '../../core/data/auth_repository.dart';
import '../../core/data/surprise_repository.dart';
import '../../core/models/advent.dart';
import '../../core/models/surprise.dart';
import '../../core/services/media_picker_service.dart';
import '../surprise/surprise_media.dart';

/// Create, change, or delete the surprise behind one door for the partner.
/// Pops with `true` when something was saved or deleted.
class SurpriseEditorPage extends StatefulWidget {
  const SurpriseEditorPage({
    super.key,
    required this.day,
    required this.couple,
    required this.repository,
    required this.mediaPicker,
    this.existing,
  });

  final DateTime day;
  final Couple couple;
  final SurpriseRepository repository;
  final MediaPickerService mediaPicker;
  final Surprise? existing;

  @override
  State<SurpriseEditorPage> createState() => _SurpriseEditorPageState();
}

class _SurpriseEditorPageState extends State<SurpriseEditorPage> {
  late final TextEditingController _note;
  late final TextEditingController _link;
  PickedMedia? _newMedia;
  bool _keepExisting = true;
  bool _busy = false;
  String? _linkError;
  String? _error;

  bool get _showsExistingMedia =>
      _newMedia == null &&
      _keepExisting &&
      (widget.existing?.hasMedia ?? false);

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.existing?.note ?? '');
    _link = TextEditingController(text: widget.existing?.link ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<PickedMedia?> Function() picker) async {
    final PickedMedia? media;
    try {
      media = await picker();
    } on Object catch (error) {
      setState(() => _error = 'Could not get the file: $error');
      return;
    }
    if (media == null || !mounted) {
      return;
    }
    if (media.bytes.length > maxUploadBytes) {
      setState(() => _error = 'Files can be at most 50 MB.');
      return;
    }
    setState(() {
      _newMedia = media;
      _error = null;
    });
  }

  void _removeMedia() {
    setState(() {
      _newMedia = null;
      _keepExisting = false;
    });
  }

  Future<void> _save() async {
    String? link;
    try {
      link = normalizeLink(_link.text);
    } on FormatException catch (error) {
      setState(() => _linkError = error.message);
      return;
    }
    final draft = SurpriseDraft(
      day: widget.day,
      recipientId: widget.couple.partner.id,
      note: _note.text,
      link: link,
      newMedia: _newMedia,
      keepExistingMedia: _keepExisting,
    );
    if (!draft.hasContent(existingMedia: widget.existing?.hasMedia ?? false)) {
      setState(() {
        _linkError = null;
        _error = 'Add a message, a link, or a file.';
      });
      return;
    }
    await _run(
      () => widget.repository.save(draft, existing: widget.existing),
      failure: 'Saving failed',
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this surprise?'),
        content: Text(
          'Door ${widget.day.day} for ${widget.couple.partner.displayName} '
          'will be empty again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.repository.delete(widget.existing!),
        failure: 'Deleting failed',
      );
    }
  }

  Future<void> _run(
    Future<Object?> Function() action, {
    required String failure,
  }) async {
    setState(() {
      _busy = true;
      _linkError = null;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is AppFailure ? error.message : '$failure: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = widget.couple.partner.displayName;
    return Scaffold(
      appBar: AppBar(
        title: Text('Door ${widget.day.day} for $partner'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete surprise',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '$partner can open this on ${formatAdventDay(widget.day)}.',
            style: theme.textTheme.bodyMedium,
          ),
          if (widget.existing?.isOpened ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$partner has already opened it.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          _mediaSection(theme),
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            enabled: !_busy,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _link,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Link (optional)',
              hintText: 'e.g. a song, a video, a place',
              prefixIcon: const Icon(Icons.link),
              border: const OutlineInputBorder(),
              errorText: _linkError,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.card_giftcard),
            label: Text(_busy ? 'Saving…' : 'Save surprise'),
          ),
        ],
      ),
    );
  }

  Widget _mediaSection(ThemeData theme) {
    final newMedia = _newMedia;
    final existing = widget.existing;
    if (newMedia == null && !_showsExistingMedia) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _pick(widget.mediaPicker.pickFromGallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Photo or video'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(widget.mediaPicker.takePhoto),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo'),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _pick(widget.mediaPicker.recordVideo),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Record video'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(widget.mediaPicker.pickFile),
            icon: const Icon(Icons.attach_file),
            label: const Text('Other file'),
          ),
        ],
      );
    }

    final Widget preview;
    final String name;
    if (newMedia != null) {
      name = newMedia.name;
      preview = newMedia.kind == MediaKind.image
          ? Image.memory(newMedia.bytes, fit: BoxFit.cover)
          : ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(child: Icon(mediaIcon(newMedia.kind), size: 48)),
            );
    } else {
      name = existing!.mediaName ?? 'Attached file';
      preview = SurpriseThumbnail(
        surprise: existing,
        repository: widget.repository,
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 200, child: preview),
          ListTile(
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remove file',
              onPressed: _busy ? null : _removeMedia,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
