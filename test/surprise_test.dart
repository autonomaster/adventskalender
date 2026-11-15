import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:adventskalender/core/data/auth_repository.dart';
import 'package:adventskalender/core/data/memory_repositories.dart';
import 'package:adventskalender/core/models/surprise.dart';

PickedMedia photo(String name) => PickedMedia(
  bytes: Uint8List.fromList([1, 2, 3]),
  name: name,
  kind: MediaKind.image,
  mimeType: 'image/jpeg',
);

void main() {
  group('normalizeLink', () {
    test('adds https to bare domains and keeps full URLs', () {
      expect(normalizeLink('  '), isNull);
      expect(normalizeLink('example.com/a'), 'https://example.com/a');
      expect(normalizeLink('http://example.com'), 'http://example.com');
    });

    test('rejects text that is not a web link', () {
      expect(() => normalizeLink('hello'), throwsFormatException);
      expect(() => normalizeLink('ftp://example.com'), throwsFormatException);
    });
  });

  test('media kind follows the file extension', () {
    expect(mediaKindForName('IMG_1.HEIC'), MediaKind.image);
    expect(mediaKindForName('clip.mov'), MediaKind.video);
    expect(mediaKindForName('poem.pdf'), MediaKind.file);
    expect(mediaKindForName('README'), MediaKind.file);
  });

  test('a couple needs exactly one partner', () {
    const carl = Profile(id: 'c', displayName: 'Carl');
    const mariana = Profile(id: 'm', displayName: 'Mariana');
    const extra = Profile(id: 'x', displayName: 'X');

    expect(coupleFromProfiles('c', [carl, mariana]).partner, mariana);
    expect(() => coupleFromProfiles('c', [carl]), throwsA(isA<AppFailure>()));
    expect(
      () => coupleFromProfiles('c', [carl, mariana, extra]),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => coupleFromProfiles('c', [mariana]),
      throwsA(isA<AppFailure>()),
    );
  });

  group('memory repositories', () {
    late DateTime now;
    late MemoryBackend backend;
    late MemoryAuthRepository auth;
    late MemorySurpriseRepository surprises;

    setUp(() async {
      now = DateTime(2026, 12, 3, 8);
      backend = MemoryBackend.demo(now: () => now);
      auth = MemoryAuthRepository(backend);
      surprises = MemorySurpriseRepository(backend);
      await auth.signIn(email: 'carl@demo', password: 'advent');
    });

    test('recipient only receives doors whose day has started', () async {
      for (final day in [3, 4]) {
        await surprises.save(
          SurpriseDraft(
            day: DateTime(2026, 12, day),
            recipientId: 'mariana',
            note: 'Door $day',
          ),
        );
      }

      expect((await surprises.receivedBy('mariana')).map((s) => s.note), [
        'Door 3',
      ]);
      now = DateTime(2026, 12, 4);
      expect((await surprises.receivedBy('mariana')).map((s) => s.note), [
        'Door 3',
        'Door 4',
      ]);
    });

    test(
      'saving the same day again replaces the surprise and its file',
      () async {
        final day = DateTime(2026, 12, 3);
        final first = await surprises.save(
          SurpriseDraft(
            day: day,
            recipientId: 'mariana',
            note: '',
            newMedia: photo('a.jpg'),
          ),
        );
        final second = await surprises.save(
          SurpriseDraft(
            day: day,
            recipientId: 'mariana',
            note: 'new',
            newMedia: photo('b.jpg'),
          ),
          existing: first,
        );

        expect(await surprises.sentBy('carl'), hasLength(1));
        expect(second.id, first.id);
        expect(second.mediaName, 'b.jpg');
        expect(backend.files.keys, [second.mediaPath]);

        final withoutMedia = await surprises.save(
          SurpriseDraft(
            day: day,
            recipientId: 'mariana',
            note: 'new',
            keepExistingMedia: false,
          ),
          existing: second,
        );
        expect(withoutMedia.hasMedia, isFalse);
        expect(backend.files, isEmpty);
      },
    );

    test('only the recipient can mark a surprise opened', () async {
      final saved = await surprises.save(
        SurpriseDraft(
          day: DateTime(2026, 12, 1),
          recipientId: 'mariana',
          note: 'hi',
        ),
      );
      await surprises.markOpened(saved);
      expect((await surprises.sentBy('carl')).single.isOpened, isFalse);

      await auth.signOut();
      await auth.signIn(email: 'mariana@demo', password: 'advent');
      await surprises.markOpened(saved);
      expect((await surprises.receivedBy('mariana')).single.openedAt, now);
    });

    test('wrong password is rejected', () async {
      await auth.signOut();
      expect(
        () => auth.signIn(email: 'carl@demo', password: 'nope'),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
