import '../models/surprise.dart';

/// User-facing failure with a message that can be shown as is.
class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Someone who named the signed-in person as their partner.
class Invitation {
  const Invitation({required this.name, required this.email});

  final String name;
  final String email;
}

/// Whether the signed-in person is connected with a partner yet.
sealed class PartnerStatus {
  const PartnerStatus();
}

class PartnerLinked extends PartnerStatus {
  const PartnerLinked(this.couple);

  final Couple couple;
}

class PartnerMissing extends PartnerStatus {
  const PartnerMissing({
    required this.me,
    this.invitedEmail,
    this.incoming = const [],
  });

  final Profile me;

  /// Whom the signed-in person invited, if anyone.
  final String? invitedEmail;

  /// People waiting for the signed-in person to accept.
  final List<Invitation> incoming;
}

enum InviteResult { invited, linked }

abstract class AuthRepository {
  bool get isSignedIn;

  /// Emits whenever the user signs in or out.
  Stream<bool> get signedInChanges;

  /// Throws [AppFailure] for wrong credentials.
  Future<void> signIn({required String email, required String password});

  /// Creates an account. Returns false when the email address has to be
  /// confirmed (link in an email) before signing in.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<PartnerStatus> loadPartnerStatus();

  /// Invites [email] as partner, or accepts their invitation. Two people are
  /// linked once both have named each other. Throws [AppFailure].
  Future<InviteResult> invitePartner(String email);

  Future<void> declineInvitation(String inviterEmail);
}
