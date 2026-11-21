import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/surprise.dart';
import 'auth_repository.dart';
import 'surprise_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AppFailure(error.message);
    }
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      return response.session != null;
    } on AuthException catch (error) {
      throw AppFailure(error.message);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<PartnerStatus> loadPartnerStatus() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      throw const AppFailure('You are signed out.');
    }
    // Row level security returns only my profile and my partner's.
    final rows = await _client
        .from('profiles')
        .select('id, display_name, partner_id');
    Profile profile(Map<String, dynamic> row) => Profile(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
    );
    final mine = rows.where((row) => row['id'] == myId).firstOrNull;
    if (mine == null) {
      throw const AppFailure(
        'Your profile is missing. Run the files in supabase/migrations.',
      );
    }
    final partnerId = mine['partner_id'] as String?;
    if (partnerId != null) {
      final partner = rows.where((row) => row['id'] == partnerId).firstOrNull;
      if (partner == null) {
        throw const AppFailure('Your partner\'s profile could not be loaded.');
      }
      return PartnerLinked(
        Couple(me: profile(mine), partner: profile(partner)),
      );
    }
    final invitation = await _client
        .from('invitations')
        .select('invitee_email')
        .maybeSingle();
    final incoming = await _client.rpc<List<dynamic>>('incoming_invitations');
    return PartnerMissing(
      me: profile(mine),
      invitedEmail: invitation?['invitee_email'] as String?,
      incoming: [
        for (final row in incoming.cast<Map<String, dynamic>>())
          Invitation(
            name: row['inviter_name'] as String,
            email: row['inviter_email'] as String,
          ),
      ],
    );
  }

  @override
  Future<InviteResult> invitePartner(String email) async {
    try {
      final result = await _client.rpc<String>(
        'invite_partner',
        params: {'partner_email': email},
      );
      return result == 'linked' ? InviteResult.linked : InviteResult.invited;
    } on PostgrestException catch (error) {
      throw AppFailure(error.message);
    }
  }

  @override
  Future<void> declineInvitation(String inviterEmail) async {
    await _client.rpc<void>(
      'decline_invitation',
      params: {'inviter_email': inviterEmail},
    );
  }
}

/// The signed-in person's test date (see supabase/migrations), or null.
Future<DateTime?> loadTestDate(SupabaseClient client) async {
  final myId = client.auth.currentUser?.id;
  if (myId == null) {
    return null;
  }
  final row = await client
      .from('profiles')
      .select('test_date')
      .eq('id', myId)
      .maybeSingle();
  final value = row?['test_date'] as String?;
  return value == null ? null : DateTime.parse(value);
}

class SupabaseSurpriseRepository implements SurpriseRepository {
  SupabaseSurpriseRepository(this._client);

  static const _bucket = 'surprises';
  static const _signedUrlSeconds = 60 * 60;

  final SupabaseClient _client;
  final Map<String, ({Uri url, DateTime expires})> _signedUrls = {};

  StorageFileApi get _files => _client.storage.from(_bucket);

  @override
  Future<List<Surprise>> sentBy(String senderId) async {
    final rows = await _client
        .from('surprises')
        .select()
        .eq('sender_id', senderId)
        .order('day');
    return rows.map(Surprise.fromRow).toList();
  }

  @override
  Future<List<Surprise>> receivedBy(String recipientId) async {
    final rows = await _client
        .from('surprises')
        .select()
        .eq('recipient_id', recipientId)
        .order('day');
    return rows.map(Surprise.fromRow).toList();
  }

  @override
  Future<Surprise> save(SurpriseDraft draft, {Surprise? existing}) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) {
      throw const AppFailure('You are signed out.');
    }
    final media = draft.newMedia;
    String? uploadedPath;
    if (media != null) {
      if (media.bytes.length > maxUploadBytes) {
        throw const AppFailure('Files can be at most 50 MB.');
      }
      uploadedPath =
          '$senderId/${dateKey(draft.day)}-'
          '${DateTime.now().millisecondsSinceEpoch}${_extension(media.name)}';
      await _files.uploadBinary(
        uploadedPath,
        media.bytes,
        fileOptions: FileOptions(contentType: media.mimeType),
      );
    }

    final keepOld =
        media == null &&
        draft.keepExistingMedia &&
        existing != null &&
        existing.hasMedia;
    final Surprise saved;
    try {
      final row = await _client
          .from('surprises')
          .upsert({
            'sender_id': senderId,
            'recipient_id': draft.recipientId,
            'day': dateKey(draft.day),
            'note': draft.note.trim(),
            'link': draft.link,
            'media_path': uploadedPath ?? (keepOld ? existing.mediaPath : null),
            'media_name': media?.name ?? (keepOld ? existing.mediaName : null),
            'media_type':
                media?.kind.name ?? (keepOld ? existing.mediaKind!.name : null),
          }, onConflict: 'sender_id,day')
          .select()
          .single();
      saved = Surprise.fromRow(row);
    } catch (_) {
      if (uploadedPath != null) {
        await _files.remove([uploadedPath]);
      }
      rethrow;
    }

    final oldPath = existing?.mediaPath;
    if (oldPath != null && oldPath != saved.mediaPath) {
      await _files.remove([oldPath]);
      _signedUrls.remove(oldPath);
    }
    return saved;
  }

  @override
  Future<void> delete(Surprise surprise) async {
    await _client.from('surprises').delete().eq('id', surprise.id);
    final path = surprise.mediaPath;
    if (path != null) {
      await _files.remove([path]);
      _signedUrls.remove(path);
    }
  }

  @override
  Future<void> markOpened(Surprise surprise) async {
    await _client.rpc(
      'mark_surprise_opened',
      params: {'surprise_id': surprise.id},
    );
  }

  @override
  Future<Uri> mediaUrl(Surprise surprise) async {
    final path = surprise.mediaPath;
    if (path == null) {
      throw StateError('Surprise ${surprise.id} has no media.');
    }
    final cached = _signedUrls[path];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    final url = Uri.parse(
      await _files.createSignedUrl(path, _signedUrlSeconds),
    );
    _signedUrls[path] = (
      url: url,
      // Renew well before the server-side expiry.
      expires: DateTime.now().add(const Duration(minutes: 50)),
    );
    return url;
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) {
      return '';
    }
    return name.substring(dot).toLowerCase();
  }
}
