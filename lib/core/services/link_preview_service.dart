import 'dart:async';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Metadata shown in a link preview card. Every field except [url] is
/// optional: a preview with only [url] means nothing could be fetched.
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  final Uri url;

  /// Trimmed and whitespace-collapsed; null if empty.
  final String? title;

  /// Trimmed and whitespace-collapsed, cut to ~200 chars; null if empty.
  final String? description;

  /// Absolute http(s) URL of a thumbnail.
  final Uri? imageUrl;

  final String? siteName;

  /// [url]'s host without a leading `www.`.
  String get host =>
      url.host.startsWith('www.') ? url.host.substring(4) : url.host;
}

/// Fetches [LinkPreview]s via oEmbed (YouTube, Spotify, Vimeo, SoundCloud) or
/// by scraping OpenGraph / Twitter / HTML meta tags.
class LinkPreviewService {
  LinkPreviewService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Future<LinkPreview>> _cache = {};

  static const _timeout = Duration(seconds: 8);
  static const _maxBodyBytes = 512 * 1024;
  static const _htmlHeaders = {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'accept-language': 'de-DE,de;q=0.9,en;q=0.8',
  };

  /// Never throws. Cached per URL string (the Future is cached, so concurrent
  /// callers share one request). Any failure (network, timeout, CORS on web,
  /// non-2xx, parse) -> `LinkPreview(url: url)`.
  Future<LinkPreview> preview(Uri url) =>
      _cache.putIfAbsent(url.toString(), () => _safeLoad(url));

  Future<LinkPreview> _safeLoad(Uri url) async {
    try {
      return await _load(url);
    } catch (_) {
      return LinkPreview(url: url);
    }
  }

  Future<LinkPreview> _load(Uri url) async {
    if (!_isHttp(url)) return LinkPreview(url: url);

    final videoId = youtubeVideoId(url);
    if (videoId != null) return _youtube(url, videoId);

    final oembedEndpoint = _oembedEndpoint(url);
    if (oembedEndpoint != null) {
      final fromOembed = await _tryOembed(url, oembedEndpoint);
      if (fromOembed != null) return fromOembed;
    }
    return _scrape(url);
  }

  Future<LinkPreview> _youtube(Uri url, String videoId) async {
    final canonical = Uri.https('www.youtube.com', '/watch', {'v': videoId});
    final endpoint = Uri.https('www.youtube.com', '/oembed', {
      'format': 'json',
      'url': canonical.toString(),
    });
    final fallbackImage = Uri.https(
      'i.ytimg.com',
      '/vi/$videoId/hqdefault.jpg',
    );
    final fromOembed = await _tryOembed(url, endpoint);
    return LinkPreview(
      url: url,
      title: fromOembed?.title,
      description: fromOembed?.description,
      imageUrl: fromOembed?.imageUrl ?? fallbackImage,
      siteName: fromOembed?.siteName ?? 'YouTube',
    );
  }

  static Uri? _oembedEndpoint(Uri url) {
    final host = url.host.toLowerCase();
    final target = url.toString();
    if (host == 'open.spotify.com') {
      return Uri.https('open.spotify.com', '/oembed', {'url': target});
    }
    if (host == 'vimeo.com' || host == 'www.vimeo.com') {
      return Uri.https('vimeo.com', '/api/oembed.json', {'url': target});
    }
    if (host == 'soundcloud.com' ||
        host == 'www.soundcloud.com' ||
        host == 'm.soundcloud.com') {
      return Uri.https('soundcloud.com', '/oembed', {
        'format': 'json',
        'url': target,
      });
    }
    return null;
  }

  /// Returns null when the endpoint fails or yields neither title nor image.
  Future<LinkPreview?> _tryOembed(Uri url, Uri endpoint) async {
    try {
      final response = await _client
          .get(endpoint, headers: const {'accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) return null;
      String? field(String key) {
        final value = json[key];
        return value is String ? value : null;
      }

      final title = _cleanText(field('title'));
      final image = _httpUri(endpoint, field('thumbnail_url'));
      if (title == null && image == null) return null;
      return LinkPreview(
        url: url,
        title: title,
        description: _truncate(
          _cleanText(field('description')) ?? _cleanText(field('author_name')),
        ),
        imageUrl: image,
        siteName: _cleanText(field('provider_name')),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LinkPreview> _scrape(Uri url) async {
    final request = http.Request('GET', url)..headers.addAll(_htmlHeaders);
    final response = await _client.send(request).timeout(_timeout);
    final stream = response.stream;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      unawaited(stream.listen(null).cancel());
      return LinkPreview(url: url);
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.startsWith('image/')) {
      unawaited(stream.listen(null).cancel());
      return LinkPreview(url: url, imageUrl: url);
    }
    if (contentType.isNotEmpty && !contentType.contains('html')) {
      unawaited(stream.listen(null).cancel());
      return LinkPreview(url: url);
    }

    final finalUrl = switch (response) {
      http.BaseResponseWithUrl(url: final redirected) => redirected,
      _ => url,
    };

    final bytes = <int>[];
    await for (final chunk in stream.timeout(_timeout)) {
      final scanFrom = bytes.length < 5 ? 0 : bytes.length - 5;
      bytes.addAll(chunk);
      if (bytes.length >= _maxBodyBytes) {
        bytes.length = _maxBodyBytes;
        break;
      }
      if (_indexOfHeadEnd(bytes, scanFrom) >= 0) break;
    }

    final parsed = parseHtmlPreview(_decode(bytes, contentType), finalUrl);
    return LinkPreview(
      url: url,
      title: parsed.title,
      description: parsed.description,
      imageUrl: parsed.imageUrl,
      siteName: parsed.siteName,
    );
  }

  /// Index of a case-insensitive `</head` in [bytes] at or after [start].
  static int _indexOfHeadEnd(List<int> bytes, int start) {
    const pattern = [0x3c, 0x2f, 0x68, 0x65, 0x61, 0x64]; // </head
    outer:
    for (var i = start; i <= bytes.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if ((bytes[i + j] | 0x20) != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static final _charsetPattern = RegExp(
    r'''charset\s*=\s*["']?([\w.:-]+)''',
    caseSensitive: false,
  );

  static String _decode(List<int> bytes, String contentType) {
    var charset = _charsetPattern.firstMatch(contentType)?.group(1);
    if (charset == null) {
      final head = latin1.decode(
        bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes,
      );
      charset = RegExp(r'<meta[^>]*>', caseSensitive: false)
          .allMatches(head)
          .map((m) => _charsetPattern.firstMatch(m.group(0)!)?.group(1))
          .nonNulls
          .firstOrNull;
    }
    switch (charset?.toLowerCase()) {
      case 'iso-8859-1' ||
          'iso8859-1' ||
          'latin1' ||
          'latin-1' ||
          'l1' ||
          'windows-1252' ||
          'cp1252' ||
          'iso-8859-15':
        return latin1.decode(bytes);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

/// Extracts preview metadata from (possibly truncated) HTML. Relative image
/// URLs are resolved against `<base href>` or [pageUrl].
LinkPreview parseHtmlPreview(String html, Uri pageUrl) {
  final document = html_parser.parse(html);

  final meta = <String, String>{};
  for (final element in document.getElementsByTagName('meta')) {
    final content = element.attributes['content']?.trim();
    if (content == null || content.isEmpty) continue;
    for (final attribute in const ['property', 'name']) {
      final key = element.attributes[attribute]?.trim().toLowerCase();
      if (key != null && key.isNotEmpty) meta.putIfAbsent(key, () => content);
    }
  }
  String? firstMeta(List<String> keys) {
    for (final key in keys) {
      final value = _cleanText(meta[key]);
      if (value != null) return value;
    }
    return null;
  }

  final titleElement =
      document.head?.querySelector('title') ?? document.querySelector('title');

  var base = pageUrl;
  final baseHref = document.querySelector('base[href]')?.attributes['href'];
  if (baseHref != null) base = _httpUri(pageUrl, baseHref) ?? pageUrl;

  final imageCandidates = [
    for (final key in const [
      'og:image:secure_url',
      'og:image',
      'og:image:url',
      'twitter:image',
      'twitter:image:src',
    ])
      meta[key],
    for (final link in document.getElementsByTagName('link'))
      if ((link.attributes['rel'] ?? '')
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .contains('image_src'))
        link.attributes['href'],
  ];
  Uri? image;
  for (final candidate in imageCandidates) {
    image = _httpUri(base, candidate);
    if (image != null) break;
  }

  return LinkPreview(
    url: pageUrl,
    title:
        firstMeta(const ['og:title', 'twitter:title']) ??
        _cleanText(titleElement?.text),
    description: _truncate(
      firstMeta(const ['og:description', 'twitter:description', 'description']),
    ),
    imageUrl: image,
    siteName: firstMeta(const ['og:site_name']),
  );
}

/// The YouTube video ID of [url], or null if it is not a YouTube video link.
/// Supports youtu.be/ID, youtube.com/watch?v=ID, /shorts/ID, /embed/ID,
/// /live/ID, /v/ID on www., m. and music. hosts and youtube-nocookie.com.
String? youtubeVideoId(Uri url) {
  if (!_isHttp(url)) return null;
  final host = url.host.toLowerCase();
  final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
  String? candidate;
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    candidate = segments.isEmpty ? null : segments.first;
  } else if (const {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  }.contains(host)) {
    if (segments.length == 1 && segments.first == 'watch') {
      candidate = url.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
      candidate = segments[1];
    }
  }
  if (candidate == null || !_videoIdPattern.hasMatch(candidate)) return null;
  return candidate;
}

final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _whitespace = RegExp(r'\s+');
const _maxDescriptionLength = 200;

bool _isHttp(Uri url) =>
    (url.scheme == 'http' || url.scheme == 'https') && url.host.isNotEmpty;

String? _cleanText(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(_whitespace, ' ').trim();
  return cleaned.isEmpty ? null : cleaned;
}

String? _truncate(String? text) {
  if (text == null || text.length <= _maxDescriptionLength) return text;
  var cut = text.substring(0, _maxDescriptionLength);
  // Don't split a surrogate pair.
  final last = cut.codeUnitAt(cut.length - 1);
  if (last >= 0xD800 && last <= 0xDBFF) cut = cut.substring(0, cut.length - 1);
  final space = cut.lastIndexOf(' ');
  if (space >= _maxDescriptionLength * 0.75) cut = cut.substring(0, space);
  return '${cut.trimRight()}…';
}

/// Resolves [reference] against [base]; null unless the result is absolute
/// http(s).
Uri? _httpUri(Uri base, String? reference) {
  final trimmed = reference?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  try {
    final resolved = base.resolve(trimmed);
    return _isHttp(resolved) ? resolved : null;
  } on FormatException {
    return null;
  }
}
