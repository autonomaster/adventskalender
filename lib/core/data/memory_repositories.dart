import 'dart:async';

import '../models/advent.dart';
import '../models/surprise.dart';
import 'auth_repository.dart';
import 'surprise_repository.dart';

class MemoryAccount {
  const MemoryAccount({
    required this.email,
    required this.password,
    required this.profile,
  });

  final String email;
  final String password;
  final Profile profile;
}

/// Shared state for the in-memory auth and surprise repositories. Used by
/// tests and by demo mode (`--dart-define=ADVENT_DEMO=true`).
class MemoryBackend {
  MemoryBackend({required this.accounts, required this.now});

  factory MemoryBackend.demo({required DateTime Function() now}) {
    return MemoryBackend(
      now: now,
      accounts: const [
        MemoryAccount(
          email: 'carl@demo',
          password: 'advent',
          profile: Profile(id: 'carl', displayName: 'Carl'),
        ),
        MemoryAccount(
          email: 'mariana@demo',
          password: 'advent',
          profile: Profile(id: 'mariana', displayName: 'Mariana'),
        ),
      ],
    );
  }

  final List<MemoryAccount> accounts;
  final DateTime Function() now;
  final List<Surprise> surprises = [];
  final Map<String, PickedMedia> files = {};
  final StreamController<bool> _signedIn = StreamController.broadcast();
  String? currentUserId;
  int _nextId = 1;

  String nextId() => 'm${_nextId++}';

  void setCurrentUser(String? id) {
    currentUserId = id;
    _signedIn.add(id != null);
  }
}

class MemoryAuthRepository implements AuthRepository {
  MemoryAuthRepository(this._backend);

  final MemoryBackend _backend;

  @override
  bool get isSignedIn => _backend.currentUserId != null;

  @override
  Stream<bool> get signedInChanges => _backend._signedIn.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final account = _backend.accounts
        .where(
          (account) =>
              account.email == email.trim().toLowerCase() &&
              account.password == password,
        )
        .firstOrNull;
    if (account == null) {
      throw const AppFailure('Invalid login credentials');
    }
    _backend.setCurrentUser(account.profile.id);
  }

  @override
  Future<void> signOut() async => _backend.setCurrentUser(null);

  @override
  Future<Couple> loadCouple() async {
    final myId = _backend.currentUserId;
    if (myId == null) {
      throw const AppFailure('You are signed out.');
    }
    return coupleFromProfiles(
      myId,
      _backend.accounts.map((account) => account.profile),
    );
  }
}

class MemorySurpriseRepository implements SurpriseRepository {
  MemorySurpriseRepository(this._backend);

  final MemoryBackend _backend;

  @override
  Future<List<Surprise>> sentBy(String senderId) async =>
      _sorted(_backend.surprises.where((s) => s.senderId == senderId));

  @override
  Future<List<Surprise>> receivedBy(String recipientId) async => _sorted(
    _backend.surprises.where(
      (s) =>
          s.recipientId == recipientId && isDoorUnlocked(s.day, _backend.now()),
    ),
  );

  @override
  Future<Surprise> save(SurpriseDraft draft, {Surprise? existing}) async {
    final senderId = _backend.currentUserId;
    if (senderId == null) {
      throw const AppFailure('You are signed out.');
    }
    final media = draft.newMedia;
    if (media != null && media.bytes.length > maxUploadBytes) {
      throw const AppFailure('Files can be at most 50 MB.');
    }
    final previous = _backend.surprises
        .where((s) => s.senderId == senderId && s.day == draft.day)
        .firstOrNull;
    final keepOld =
        media == null && draft.keepExistingMedia && previous?.hasMedia == true;
    String? mediaPath = keepOld ? previous!.mediaPath : null;
    if (media != null) {
      mediaPath = '$senderId/${_backend.nextId()}-${media.name}';
      _backend.files[mediaPath] = media;
    }
    final saved = Surprise(
      id: previous?.id ?? _backend.nextId(),
      senderId: senderId,
      recipientId: draft.recipientId,
      day: draft.day,
      note: draft.note.trim(),
      link: draft.link,
      mediaPath: mediaPath,
      mediaName: media?.name ?? (keepOld ? previous!.mediaName : null),
      mediaKind: media?.kind ?? (keepOld ? previous!.mediaKind : null),
      createdAt: previous?.createdAt ?? _backend.now(),
      openedAt: previous?.openedAt,
    );
    if (previous != null) {
      _backend.surprises.remove(previous);
      if (previous.mediaPath != null && previous.mediaPath != mediaPath) {
        _backend.files.remove(previous.mediaPath);
      }
    }
    _backend.surprises.add(saved);
    return saved;
  }

  @override
  Future<void> delete(Surprise surprise) async {
    _backend.surprises.removeWhere((s) => s.id == surprise.id);
    _backend.files.remove(surprise.mediaPath);
  }

  @override
  Future<void> markOpened(Surprise surprise) async {
    final index = _backend.surprises.indexWhere(
      (s) =>
          s.id == surprise.id &&
          s.recipientId == _backend.currentUserId &&
          s.openedAt == null,
    );
    if (index >= 0) {
      _backend.surprises[index] = _backend.surprises[index].copyWith(
        openedAt: _backend.now(),
      );
    }
  }

  @override
  Future<Uri> mediaUrl(Surprise surprise) async {
    final media = _backend.files[surprise.mediaPath];
    if (media == null) {
      throw StateError('Surprise ${surprise.id} has no media.');
    }
    return Uri.dataFromBytes(
      media.bytes,
      mimeType: media.mimeType ?? 'application/octet-stream',
    );
  }

  static List<Surprise> _sorted(Iterable<Surprise> surprises) =>
      surprises.toList()..sort((a, b) => a.day.compareTo(b.day));
}
