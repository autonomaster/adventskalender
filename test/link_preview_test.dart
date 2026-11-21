import 'dart:async';
import 'dart:convert';

import 'package:adventskalender/core/services/link_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _html(String body, {int status = 200}) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

void main() {
  final page = Uri.parse('https://example.com/blog/post.html');

  group('parseHtmlPreview', () {
    test('prefers og over twitter over <title> and meta description', () {
      const html = '''
<html><head>
  <title>Plain title</title>
  <meta name="twitter:title" content="Twitter title">
  <meta property="og:title" content="OG title">
  <meta name="description" content="Plain description">
  <meta name="twitter:description" content="Twitter description">
  <meta property="og:description" content="OG description">
  <meta property="og:site_name" content="Example Site">
</head></html>''';
      final preview = parseHtmlPreview(html, page);
      expect(preview.title, 'OG title');
      expect(preview.description, 'OG description');
      expect(preview.siteName, 'Example Site');
    });

    test('falls back to twitter tags, then <title> and meta description', () {
      final twitter = parseHtmlPreview('''
<head><title>Plain title</title>
<meta name="twitter:title" content="Twitter title">
<meta name="twitter:description" content="Twitter description">
<meta name="description" content="Plain description"></head>''', page);
      expect(twitter.title, 'Twitter title');
      expect(twitter.description, 'Twitter description');

      final plain = parseHtmlPreview('''
<head><title>Plain title</title>
<meta name="description" content="Plain description"></head>''', page);
      expect(plain.title, 'Plain title');
      expect(plain.description, 'Plain description');
      expect(plain.imageUrl, isNull);
      expect(plain.siteName, isNull);
    });

    test('matches property and name attribute values case-insensitively', () {
      final preview = parseHtmlPreview('''
<head><meta PROPERTY="OG:Title" content="Shouted">
<meta name="OG:IMAGE" content="https://img.example.com/a.png"></head>''', page);
      expect(preview.title, 'Shouted');
      expect(preview.imageUrl, Uri.parse('https://img.example.com/a.png'));
    });

    test('image priority: secure_url > og:image > ... > link image_src', () {
      Uri? imageOf(String head) =>
          parseHtmlPreview('<head>$head</head>', page).imageUrl;

      const linkTag = '<link rel="image_src" href="https://x.com/link.png">';
      const twitterSrc =
          '<meta name="twitter:image:src" content="https://x.com/tsrc.png">';
      const twitter =
          '<meta name="twitter:image" content="https://x.com/t.png">';
      const ogUrl =
          '<meta property="og:image:url" content="https://x.com/ogurl.png">';
      const og = '<meta property="og:image" content="https://x.com/og.png">';
      const secure =
          '<meta property="og:image:secure_url" content="https://x.com/s.png">';

      expect(imageOf(linkTag), Uri.parse('https://x.com/link.png'));
      expect(
        imageOf('$linkTag$twitterSrc'),
        Uri.parse('https://x.com/tsrc.png'),
      );
      expect(
        imageOf('$linkTag$twitterSrc$twitter'),
        Uri.parse('https://x.com/t.png'),
      );
      expect(
        imageOf('$linkTag$twitter$ogUrl'),
        Uri.parse('https://x.com/ogurl.png'),
      );
      expect(imageOf('$twitter$ogUrl$og'), Uri.parse('https://x.com/og.png'));
      expect(imageOf('$og$secure'), Uri.parse('https://x.com/s.png'));
    });

    test('resolves relative and protocol-relative image URLs', () {
      Uri? imageOf(String src) => parseHtmlPreview(
        '<head><meta property="og:image" content="$src"></head>',
        page,
      ).imageUrl;

      expect(
        imageOf('/img/cover.jpg'),
        Uri.parse('https://example.com/img/cover.jpg'),
      );
      expect(
        imageOf('cover.jpg'),
        Uri.parse('https://example.com/blog/cover.jpg'),
      );
      expect(
        imageOf('//cdn.example.com/c.jpg'),
        Uri.parse('https://cdn.example.com/c.jpg'),
      );
    });

    test('skips non-http image candidates for the next one', () {
      final preview = parseHtmlPreview('''
<head><meta property="og:image" content="data:image/png;base64,AAAA">
<meta name="twitter:image" content="https://x.com/t.png"></head>''', page);
      expect(preview.imageUrl, Uri.parse('https://x.com/t.png'));
    });

    test('decodes entities and collapses whitespace', () {
      final preview = parseHtmlPreview(
        '''
<head><title>
   Tom &amp; Jerry
   &#8211;  M&uuml;nchen
</title>
<meta name="description" content="  &quot;Quoted&quot;&#10;  next&nbsp;line  "></head>''',
        page,
      );
      expect(preview.title, 'Tom & Jerry – München');
      expect(preview.description, '"Quoted" next line');
    });

    test('empty values become null', () {
      final preview = parseHtmlPreview('''
<head><title>   </title><meta property="og:title" content="  ">
<meta property="og:site_name" content=""></head>''', page);
      expect(preview.title, isNull);
      expect(preview.siteName, isNull);
    });

    test('cuts long descriptions to about 200 chars with an ellipsis', () {
      final long = List.filled(80, 'word').join(' ');
      final preview = parseHtmlPreview(
        '<head><meta name="description" content="$long"></head>',
        page,
      );
      expect(preview.description!.length, lessThanOrEqualTo(201));
      expect(preview.description!.length, greaterThan(150));
      expect(preview.description, endsWith('word…'));
      expect(long, startsWith(preview.description!.replaceAll('…', '')));
    });
  });

  group('youtubeVideoId', () {
    const id = 'dQw4w9WgXcQ';
    for (final link in [
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc&t=42',
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?feature=share&v=$id',
      'http://m.youtube.com/watch?v=$id&t=10s',
      'https://music.youtube.com/watch?v=$id&list=RDAMVM',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id?autoplay=1',
    ]) {
      test(link, () => expect(youtubeVideoId(Uri.parse(link)), id));
    }

    for (final link in [
      'https://example.com/watch?v=$id',
      'https://vimeo.com/123456789',
      'https://www.youtube.com/@somechannel',
      'https://www.youtube.com/watch?v=tooShort',
      'https://youtu.be/',
    ]) {
      test(
        'rejects $link',
        () => expect(youtubeVideoId(Uri.parse(link)), isNull),
      );
    }
  });

  group('LinkPreview.host', () {
    test('strips a leading www.', () {
      expect(
        LinkPreview(url: Uri.parse('https://www.example.com/a')).host,
        'example.com',
      );
      expect(
        LinkPreview(url: Uri.parse('https://de.wikipedia.org/')).host,
        'de.wikipedia.org',
      );
    });
  });

  group('LinkPreviewService', () {
    test('scrapes HTML pages with a browser-like request', () async {
      late http.Request seen;
      final service = LinkPreviewService(
        client: MockClient((request) async {
          seen = request;
          return _html('''
<html><head><title>Ignored</title>
<meta property="og:title" content="Advent &amp; Co">
<meta property="og:description" content="Twenty-four doors">
<meta property="og:image" content="/door.png">
<meta property="og:site_name" content="Calendar">
</head><body>…</body></html>''');
        }),
      );
      final url = Uri.parse('https://www.example.com/advent');
      final preview = await service.preview(url);

      expect(preview.url, url);
      expect(preview.title, 'Advent & Co');
      expect(preview.description, 'Twenty-four doors');
      expect(preview.imageUrl, Uri.parse('https://www.example.com/door.png'));
      expect(preview.siteName, 'Calendar');
      expect(seen.headers['user-agent'], contains('Mozilla'));
      expect(seen.headers['accept'], contains('text/html'));
    });

    test('resolves images against the final URL after redirects', () async {
      final service = LinkPreviewService(
        client: _RedirectingClient(
          Uri.parse('https://cdn.example.org/articles/42'),
          '<head><meta property="og:image" content="pic.jpg">',
        ),
      );
      final url = Uri.parse('https://short.link/x');
      final preview = await service.preview(url);
      expect(preview.url, url);
      expect(
        preview.imageUrl,
        Uri.parse('https://cdn.example.org/articles/pic.jpg'),
      );
    });

    test('decodes latin1 pages using the content-type charset', () async {
      final service = LinkPreviewService(
        client: MockClient(
          (_) async => http.Response.bytes(
            latin1.encode('<head><title>Grüße aus Köln</title></head>'),
            200,
            headers: {'content-type': 'text/html; charset=ISO-8859-1'},
          ),
        ),
      );
      final preview = await service.preview(Uri.parse('https://example.de/'));
      expect(preview.title, 'Grüße aus Köln');
    });

    test('stops reading the body once </head> was seen', () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final service = LinkPreviewService(
        client: MockClient.streaming((request, _) async {
          body.add(utf8.encode('<html><head><title>Early</title></HEAD>'));
          // Never closed: the service must not wait for the rest.
          return http.StreamedResponse(
            body.stream,
            200,
            headers: {'content-type': 'text/html'},
          );
        }),
      );
      final preview = await service
          .preview(Uri.parse('https://example.com/huge'))
          .timeout(const Duration(seconds: 2));
      expect(preview.title, 'Early');
      expect(cancelled, isTrue);
    });

    test('uses the link itself as image for image content types', () async {
      final url = Uri.parse('https://example.com/photo.jpg');
      final service = LinkPreviewService(
        client: MockClient(
          (_) async => http.Response.bytes(
            [0xff, 0xd8, 0xff],
            200,
            headers: {'content-type': 'image/jpeg'},
          ),
        ),
      );
      final preview = await service.preview(url);
      expect(preview.imageUrl, url);
      expect(preview.title, isNull);
    });

    test('non-HTML content yields a bare preview', () async {
      final service = LinkPreviewService(
        client: MockClient(
          (_) async => http.Response(
            '%PDF-1.7',
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        ),
      );
      final preview = await service.preview(
        Uri.parse('https://example.com/doc.pdf'),
      );
      _expectBare(preview);
    });

    test('404 yields a preview with only the url', () async {
      final url = Uri.parse('https://example.com/missing');
      final service = LinkPreviewService(
        client: MockClient(
          (_) async => _html(
            '<head><title>Not found</title>'
            '<meta property="og:image" content="/404.png"></head>',
            status: 404,
          ),
        ),
      );
      final preview = await service.preview(url);
      expect(preview.url, url);
      _expectBare(preview);
    });

    test('client errors yield a preview with only the url', () async {
      final url = Uri.parse('https://unreachable.example/');
      final service = LinkPreviewService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final preview = await service.preview(url);
      expect(preview.url, url);
      _expectBare(preview);
    });

    test('concurrent and repeated calls share one request', () async {
      var requests = 0;
      final service = LinkPreviewService(
        client: MockClient((_) async {
          requests++;
          return _html('<title>Once</title>');
        }),
      );
      final url = Uri.parse('https://example.com/cached');
      final results = await Future.wait([
        service.preview(url),
        service.preview(Uri.parse('https://example.com/cached')),
      ]);
      final again = await service.preview(url);
      expect(requests, 1);
      expect([...results, again].map((p) => p.title), everyElement('Once'));
    });

    test('YouTube uses oEmbed and never scrapes the watch page', () async {
      final requested = <Uri>[];
      final service = LinkPreviewService(
        client: MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            jsonEncode({
              'title': 'Never Gonna Give You Up',
              'author_name': 'Rick Astley',
              'provider_name': 'YouTube',
              'thumbnail_url':
                  'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final url = Uri.parse('https://youtu.be/dQw4w9WgXcQ');
      final preview = await service.preview(url);

      expect(preview.url, url);
      expect(preview.title, 'Never Gonna Give You Up');
      expect(preview.description, 'Rick Astley');
      expect(preview.siteName, 'YouTube');
      expect(
        preview.imageUrl,
        Uri.parse('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'),
      );
      expect(requested, hasLength(1));
      expect(requested.single.host, 'www.youtube.com');
      expect(requested.single.path, '/oembed');
      expect(
        requested.single.queryParameters['url'],
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('YouTube oEmbed failure still yields the ytimg thumbnail', () async {
      final service = LinkPreviewService(
        client: MockClient((_) async => http.Response('Unauthorized', 401)),
      );
      final preview = await service.preview(
        Uri.parse('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
      );
      expect(
        preview.imageUrl,
        Uri.parse('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'),
      );
      expect(preview.title, isNull);
    });

    test('Spotify oEmbed failure falls through to HTML scraping', () async {
      final requested = <Uri>[];
      final service = LinkPreviewService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.path == '/oembed') throw http.ClientException('x');
          return _html(
            '<head><meta property="og:title" content="Song"></head>',
          );
        }),
      );
      final url = Uri.parse('https://open.spotify.com/track/abc');
      final preview = await service.preview(url);
      expect(preview.title, 'Song');
      expect(requested.map((u) => u.path), ['/oembed', '/track/abc']);
    });

    test('Spotify oEmbed maps title, thumbnail and provider', () async {
      final service = LinkPreviewService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'title': 'Last Christmas',
              'thumbnail_url': 'https://image-cdn.spotifycdn.com/abc',
              'provider_name': 'Spotify',
            }),
            200,
          ),
        ),
      );
      final preview = await service.preview(
        Uri.parse('https://open.spotify.com/track/abc'),
      );
      expect(preview.title, 'Last Christmas');
      expect(
        preview.imageUrl,
        Uri.parse('https://image-cdn.spotifycdn.com/abc'),
      );
      expect(preview.siteName, 'Spotify');
    });
  });
}

void _expectBare(LinkPreview preview) {
  expect(preview.title, isNull);
  expect(preview.description, isNull);
  expect(preview.imageUrl, isNull);
  expect(preview.siteName, isNull);
}

/// Mimics IOClient after following redirects: the response reports the final
/// URL. (MockClient re-wraps responses and drops it.)
class _RedirectingClient extends http.BaseClient {
  _RedirectingClient(this.finalUrl, this.body);

  final Uri finalUrl;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      _ResponseWithUrl(
        http.ByteStream.fromBytes(utf8.encode(body)),
        200,
        headers: {'content-type': 'text/html'},
        url: finalUrl,
      );
}

class _ResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _ResponseWithUrl(
    super.stream,
    super.statusCode, {
    super.headers,
    required this.url,
  });

  @override
  final Uri url;
}
