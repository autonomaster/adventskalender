import '../models/surprise.dart';

/// Largest file accepted for upload (matches the storage bucket limit).
const int maxUploadBytes = 50 * 1024 * 1024;

abstract class SurpriseRepository {
  /// Everything [senderId] prepared, ordered by day.
  Future<List<Surprise>> sentBy(String senderId);

  /// Surprises for [recipientId] the server has released, ordered by day.
  /// Callers still check [isDoorUnlocked] against the local clock.
  Future<List<Surprise>> receivedBy(String recipientId);

  /// Creates or replaces the sender's surprise for the draft's day.
  Future<Surprise> save(SurpriseDraft draft, {Surprise? existing});

  Future<void> delete(Surprise surprise);

  Future<void> markOpened(Surprise surprise);

  /// Short-lived URL for the surprise's media.
  Future<Uri> mediaUrl(Surprise surprise);
}

String dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
