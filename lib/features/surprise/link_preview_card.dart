import 'package:flutter/material.dart';

import '../../core/services/link_preview_service.dart';
import '../../ui/riso.dart';
import 'surprise_media.dart';

/// Card with thumbnail, title, description and host of a web link.
/// Tapping it opens the link.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({super.key, required this.url, required this.service});

  final Uri url;
  final LinkPreviewService service;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreview>(
      future: service.preview(url),
      builder: (context, snapshot) {
        final preview = snapshot.data ?? LinkPreview(url: url);
        final loading = snapshot.connectionState != ConnectionState.done;
        final theme = Theme.of(context);
        final image = preview.imageUrl;
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openExternal(context, url),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (image != null)
                  AspectRatio(aspectRatio: 1.91, child: LinkImage(url: image)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preview.title ?? url.toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (preview.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                preview.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              preview.siteName ?? preview.host,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Riso.red,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Square-ish thumbnail for a link: its preview image, or the host name.
class LinkThumbnail extends StatelessWidget {
  const LinkThumbnail({super.key, required this.url, required this.service});

  final Uri url;
  final LinkPreviewService service;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreview>(
      future: service.preview(url),
      builder: (context, snapshot) {
        final preview = snapshot.data ?? LinkPreview(url: url);
        final image = preview.imageUrl;
        if (image != null) {
          return LinkImage(url: image);
        }
        return ColoredBox(
          color: Riso.paperShade,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 32, color: Riso.ink),
                  const SizedBox(height: 4),
                  Text(
                    preview.title ?? preview.host,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class LinkImage extends StatelessWidget {
  const LinkImage({super.key, required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url.toString(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Riso.paperShade,
        child: Center(child: Icon(Icons.link, color: Riso.ink)),
      ),
    );
  }
}
