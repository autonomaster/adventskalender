import '../models/surprise.dart';

/// User-facing failure with a message that can be shown as is.
class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  bool get isSignedIn;

  /// Emits whenever the user signs in or out.
  Stream<bool> get signedInChanges;

  /// Throws [AppFailure] for wrong credentials.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Loads the signed-in person and their partner.
  /// Throws [AppFailure] when the two accounts are not set up.
  Future<Couple> loadCouple();
}

Couple coupleFromProfiles(String myId, Iterable<Profile> profiles) {
  final me = profiles.where((profile) => profile.id == myId).firstOrNull;
  if (me == null) {
    throw const AppFailure(
      'Your profile is missing. Run supabase/schema.sql before creating the '
      'accounts, or insert your profile row manually.',
    );
  }
  final others = profiles.where((profile) => profile.id != myId).toList();
  if (others.isEmpty) {
    throw const AppFailure(
      'No partner account yet. Create the second account in Supabase.',
    );
  }
  if (others.length > 1) {
    throw const AppFailure(
      'More than two accounts exist. This calendar is made for exactly two '
      'people; delete the extra accounts in Supabase.',
    );
  }
  return Couple(me: me, partner: others.single);
}
