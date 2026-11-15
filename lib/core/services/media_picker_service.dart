import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/surprise.dart';

/// Picks photos, videos, and other files from the device.
class MediaPickerService {
  MediaPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Photo or video from the gallery.
  Future<PickedMedia?> pickFromGallery() async =>
      _fromXFile(await _picker.pickMedia(imageQuality: 85, maxWidth: 2560));

  Future<PickedMedia?> takePhoto() async => _fromXFile(
    await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2560,
    ),
  );

  Future<PickedMedia?> recordVideo() async => _fromXFile(
    await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    ),
  );

  Future<PickedMedia?> pickFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) {
      return null;
    }
    return PickedMedia(
      bytes: await file.readAsBytes(),
      name: file.name,
      kind: mediaKindForName(file.name),
    );
  }

  static Future<PickedMedia?> _fromXFile(XFile? file) async {
    if (file == null) {
      return null;
    }
    final mimeType = file.mimeType;
    final MediaKind kind;
    if (mimeType != null && mimeType.startsWith('image/')) {
      kind = MediaKind.image;
    } else if (mimeType != null && mimeType.startsWith('video/')) {
      kind = MediaKind.video;
    } else {
      kind = mediaKindForName(file.name);
    }
    return PickedMedia(
      bytes: await file.readAsBytes(),
      name: file.name,
      kind: kind,
      mimeType: mimeType,
    );
  }
}
