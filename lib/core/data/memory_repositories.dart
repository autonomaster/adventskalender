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
/// tests and by demo mode (`--dart-define=ADVENT_DEMO=true`). Mirrors the
/// partner rules of supabase/migrations/003_partners.sql.
class MemoryBackend {
  MemoryBackend({required List<MemoryAccount> accounts, required this.now})
    : accounts = [...accounts];

  /// Carl and Mariana, already linked.
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
    )..partners.addAll({'carl': 'mariana', 'mariana': 'carl'});
  }

  final List<MemoryAccount> accounts;
  final DateTime Function() now;
  final List<Surprise> surprises = [];
  final Map<String, PickedMedia> files = {};

  /// Person id → partner id, always symmetric.
  final Map<String, String> partners = {};

  /// Inviter id → invited email.
  final Map<String, String> invitations = {};
  final StreamController<bool> _signedIn = StreamController.broadcast();
  String? currentUserId;
  int _nextId = 1;

  String nextId() => 'm${_nextId++}';

  void setCurrentUser(String? id) {
    currentUserId = id;
    _signedIn.add(id != null);
  }

  MemoryAccount accountById(String id) =>
      accounts.firstWhere((account) => account.profile.id == id);

  MemoryAccount? accountByEmail(String email) => accounts
      .where((account) => account.email == email.trim().toLowerCase())
      .firstOrNull;
}

class MemoryAuthRepository implements AuthRepository {
  MemoryAuthRepository(this._backend);

  final MemoryBackend _backend;

  @override
  bool get isSignedIn => _backend.currentUserId != null;

  @override
  Stream<bool> get signedInChanges => _backend._signedIn.stream;

  String get _myId {
    final id = _backend.currentUserId;
    if (id == null) {
      throw const AppFailure('You are signed out.');
    }
    return id;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final account = _backend.accountByEmail(email);
    if (account == null || account.password != password) {
      throw const AppFailure('Invalid login credentials');
    }
    _backend.setCurrentUser(account.profile.id);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_backend.accountByEmail(email) != null) {
      throw const AppFailure('User already registered');
    }
    final account = MemoryAccount(
      email: email.trim().toLowerCase(),
      password: password,
      profile: Profile(id: _backend.nextId(), displayName: displayName.trim()),
    );
    _backend.accounts.add(account);
    _backend.setCurrentUser(account.profile.id);
    return true;
  }

  @override
  Future<void> signOut() async => _backend.setCurrentUser(null);

  @override
  Future<PartnerStatus> loadPartnerStatus() async {
    final me = _backend.accountById(_myId);
    final partnerId = _backend.partners[_myId];
    if (partnerId != null) {
      return PartnerLinked(
        Couple(
          me: me.profile,
          partner: _backend.accountById(partnerId).profile,
        ),
      );
    }
    return PartnerMissing(
      me: me.profile,
      invitedEmail: _backend.invitations[_myId],
      incoming: [
        for (final MapEntry(key: inviterId, value: email)
            in _backend.invitations.entries)
          if (email == me.email && !_backend.partners.containsKey(inviterId))
            Invitation(
              name: _backend.accountById(inviterId).profile.displayName,
              email: _backend.accountById(inviterId).email,
            ),
      ],
    );
  }

  @override
  Future<InviteResult> invitePartner(String email) async {
    final myId = _myId;
    final target = email.trim().toLowerCase();
    if (!target.contains('@')) {
      throw const AppFailure('Enter a valid email address.');
    }
    final me = _backend.accountById(myId);
    if (target == me.email) {
      throw const AppFailure('That is your own email address.');
    }
    if (_backend.partners.containsKey(myId)) {
      throw const AppFailure('You are already connected with a partner.');
    }
    final other = _backend.accountByEmail(target);
    if (other != null &&
        _backend.invitations[other.profile.id] == me.email &&
        !_backend.partners.containsKey(other.profile.id)) {
      _backend.partners
        ..[myId] = other.profile.id
        ..[other.profile.id] = myId;
      _backend.invitations
        ..remove(myId)
        ..remove(other.profile.id);
      return InviteResult.linked;
    }
    _backend.invitations[myId] = target;
    return InviteResult.invited;
  }

  @override
  Future<void> declineInvitation(String inviterEmail) async {
    final me = _backend.accountById(_myId);
    final inviter = _backend.accountByEmail(inviterEmail);
    if (inviter != null &&
        _backend.invitations[inviter.profile.id] == me.email) {
      _backend.invitations.remove(inviter.profile.id);
    }
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
    if (draft.recipientId != _backend.partners[senderId]) {
      throw const AppFailure('You can only fill your partner\'s tree.');
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
