import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_repository.dart';
import 'data/memory_repositories.dart';
import 'data/supabase_repositories.dart';
import 'data/surprise_repository.dart';
import 'services/link_preview_service.dart';
import 'services/media_picker_service.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _demo = bool.fromEnvironment('ADVENT_DEMO');
const _demoToday = String.fromEnvironment('ADVENT_DEMO_TODAY');

class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.surprises,
    required this.media,
    required this.linkPreviews,
    required this.now,
    this.signInHint,
  });

  final AuthRepository auth;
  final SurpriseRepository surprises;
  final MediaPickerService media;
  final LinkPreviewService linkPreviews;
  final DateTime Function() now;

  /// Shown on the sign-in screen, e.g. demo credentials.
  final String? signInHint;

  static Future<AppDependencies> create() async {
    if (_demo) {
      return demo(
        now: _demoToday.isEmpty
            ? DateTime.now
            : () => DateTime.parse(_demoToday),
      );
    }
    if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
      throw const AppFailure(
        'Supabase is not configured. Start the app with '
        '--dart-define-from-file=supabase.json (see README), or with '
        '--dart-define=ADVENT_DEMO=true to try it without a backend.',
      );
    }
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    final client = Supabase.instance.client;
    return AppDependencies(
      auth: SupabaseAuthRepository(client),
      surprises: SupabaseSurpriseRepository(client),
      media: MediaPickerService(),
      linkPreviews: LinkPreviewService(),
      now: DateTime.now,
    );
  }

  /// In-memory backend with two demo accounts; nothing leaves the device.
  static AppDependencies demo({
    required DateTime Function() now,
    LinkPreviewService? linkPreviews,
  }) {
    final backend = MemoryBackend.demo(now: now);
    return AppDependencies(
      auth: MemoryAuthRepository(backend),
      surprises: MemorySurpriseRepository(backend),
      media: MediaPickerService(),
      linkPreviews: linkPreviews ?? LinkPreviewService(),
      now: now,
      signInHint:
          'Demo mode: sign in as carl@demo or mariana@demo, password "advent". '
          'Data is lost when the app closes.',
    );
  }
}
