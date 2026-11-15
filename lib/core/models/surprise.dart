import 'dart:typed_data';

enum MediaKind {
  image,
  video,
  file;

  static MediaKind? parse(String? value) {
    for (final kind in values) {
      if (kind.name == value) {
        return kind;
      }
    }
    return null;
  }
}

class Profile {
  const Profile({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

/// The signed-in person and the one they exchange surprises with.
class Couple {
  const Couple({required this.me, required this.partner});

  final Profile me;
  final Profile partner;
}

class Surprise {
  const Surprise({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.day,
    required this.note,
    required this.createdAt,
    this.link,
    this.mediaPath,
    this.mediaName,
    this.mediaKind,
    this.openedAt,
  });

  factory Surprise.fromRow(Map<String, dynamic> row) {
    return Surprise(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      recipientId: row['recipient_id'] as String,
      day: DateTime.parse(row['day'] as String),
      note: row['note'] as String? ?? '',
      link: row['link'] as String?,
      mediaPath: row['media_path'] as String?,
      mediaName: row['media_name'] as String?,
      mediaKind: MediaKind.parse(row['media_type'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      openedAt: row['opened_at'] == null
          ? null
          : DateTime.parse(row['opened_at'] as String).toLocal(),
    );
  }

  final String id;
  final String senderId;
  final String recipientId;

  /// Local date of the door (December 1-24).
  final DateTime day;
  final String note;
  final String? link;
  final String? mediaPath;
  final String? mediaName;
  final MediaKind? mediaKind;
  final DateTime createdAt;
  final DateTime? openedAt;

  bool get hasMedia => mediaPath != null && mediaKind != null;
  bool get isOpened => openedAt != null;

  Surprise copyWith({DateTime? openedAt}) {
    return Surprise(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      day: day,
      note: note,
      createdAt: createdAt,
      link: link,
      mediaPath: mediaPath,
      mediaName: mediaName,
      mediaKind: mediaKind,
      openedAt: openedAt ?? this.openedAt,
    );
  }
}

/// A file chosen on this device, not uploaded yet.
class PickedMedia {
  const PickedMedia({
    required this.bytes,
    required this.name,
    required this.kind,
    this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final MediaKind kind;
  final String? mimeType;
}

/// What the sender wants behind a door.
class SurpriseDraft {
  const SurpriseDraft({
    required this.day,
    required this.recipientId,
    required this.note,
    this.link,
    this.newMedia,
    this.keepExistingMedia = true,
  });

  final DateTime day;
  final String recipientId;
  final String note;
  final String? link;

  /// Replaces any existing media when set.
  final PickedMedia? newMedia;

  /// When false and [newMedia] is null, existing media is removed.
  final bool keepExistingMedia;

  bool hasContent({required bool existingMedia}) =>
      note.trim().isNotEmpty ||
      link != null ||
      newMedia != null ||
      (existingMedia && keepExistingMedia);
}

/// Accepts "example.com/x" or full http(s) URLs; returns null when empty.
/// Throws [FormatException] for anything that is not a web link.
String? normalizeLink(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      !uri.host.contains('.')) {
    throw const FormatException('Enter a web link like example.com');
  }
  return uri.toString();
}

MediaKind mediaKindForName(String name) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  const images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp'};
  const videos = {'mp4', 'mov', 'm4v', 'webm', '3gp', 'mkv', 'avi'};
  if (images.contains(extension)) {
    return MediaKind.image;
  }
  if (videos.contains(extension)) {
    return MediaKind.video;
  }
  return MediaKind.file;
}
