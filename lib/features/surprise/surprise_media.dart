import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/surprise_repository.dart';
import '../../core/models/surprise.dart';

IconData mediaIcon(MediaKind? kind) => switch (kind) {
  MediaKind.image => Icons.photo_outlined,
  MediaKind.video => Icons.movie_outlined,
  MediaKind.file => Icons.insert_drive_file_outlined,
  null => Icons.notes,
};

/// Short description like "Photo · message · link".
String surpriseSummary(Surprise surprise) {
  final parts = [
    if (surprise.mediaKind == MediaKind.image) 'Photo',
    if (surprise.mediaKind == MediaKind.video) 'Video',
    if (surprise.mediaKind == MediaKind.file) surprise.mediaName ?? 'File',
    if (surprise.note.isNotEmpty) 'message',
    if (surprise.link != null) 'link',
  ];
  final text = parts.join(' · ');
  return text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1);
}

Future<void> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $uri')));
  }
}

Widget _image(Uri url, {BoxFit fit = BoxFit.contain}) {
  final data = url.data;
  if (data != null) {
    return Image.memory(data.contentAsBytes(), fit: fit);
  }
  return Image.network(
    url.toString(),
    fit: fit,
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (context, error, stackTrace) =>
        const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
  );
}

/// Resolves the media URL once per surprise, not on every rebuild.
class _MediaUrlBuilder extends StatefulWidget {
  const _MediaUrlBuilder({
    required this.surprise,
    required this.repository,
    required this.builder,
  });

  final Surprise surprise;
  final SurpriseRepository repository;
  final AsyncWidgetBuilder<Uri> builder;

  @override
  State<_MediaUrlBuilder> createState() => _MediaUrlBuilderState();
}

class _MediaUrlBuilderState extends State<_MediaUrlBuilder> {
  late Future<Uri> _url;

  @override
  void initState() {
    super.initState();
    _url = widget.repository.mediaUrl(widget.surprise);
  }

  @override
  void didUpdateWidget(_MediaUrlBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surprise.mediaPath != widget.surprise.mediaPath) {
      _url = widget.repository.mediaUrl(widget.surprise);
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Uri>(future: _url, builder: widget.builder);
}

/// Full-size media for the surprise viewer.
class SurpriseMediaView extends StatelessWidget {
  const SurpriseMediaView({
    super.key,
    required this.surprise,
    required this.repository,
  });

  final Surprise surprise;
  final SurpriseRepository repository;

  @override
  Widget build(BuildContext context) {
    return _MediaUrlBuilder(
      surprise: surprise,
      repository: repository,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MediaMessage(
            icon: Icons.cloud_off,
            text: 'The file could not be loaded.',
          );
        }
        final url = snapshot.data;
        if (url == null) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return switch (surprise.mediaKind!) {
          MediaKind.image => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(child: _image(url)),
          ),
          MediaKind.video => _VideoView(url: url),
          MediaKind.file => Card(
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(surprise.mediaName ?? 'File'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openExternal(context, url),
            ),
          ),
        };
      },
    );
  }
}

/// Square preview for grids and the editor.
class SurpriseThumbnail extends StatelessWidget {
  const SurpriseThumbnail({
    super.key,
    required this.surprise,
    required this.repository,
  });

  final Surprise surprise;
  final SurpriseRepository repository;

  @override
  Widget build(BuildContext context) {
    if (surprise.mediaKind != MediaKind.image) {
      final scheme = Theme.of(context).colorScheme;
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: surprise.hasMedia || surprise.note.isEmpty
              ? Icon(
                  surprise.hasMedia
                      ? mediaIcon(surprise.mediaKind)
                      : Icons.link,
                  size: 40,
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    surprise.note,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }
    return _MediaUrlBuilder(
      surprise: surprise,
      repository: repository,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) {
          return Center(
            child: snapshot.hasError
                ? const Icon(Icons.broken_image_outlined)
                : const CircularProgressIndicator(),
          );
        }
        return _image(url, fit: BoxFit.cover);
      },
    );
  }
}

class _MediaMessage extends StatelessWidget {
  const _MediaMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.url});

  final Uri url;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(widget.url);
    _initialized = _controller.initialize().then((_) => _controller.play());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialized,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MediaMessage(
            icon: Icons.videocam_off_outlined,
            text: 'The video could not be played.',
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: GestureDetector(
              onTap: _togglePlay,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_controller),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) => value.isPlaying
                        ? const SizedBox.shrink()
                        : const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 72,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                  VideoProgressIndicator(_controller, allowScrubbing: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
