import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_runtime_service.dart';

class FirebaseStorageGateway {
  const FirebaseStorageGateway();

  Future<String> uploadUserFile({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    if (!FirebaseRuntimeService.instance.initialized) {
      throw StateError('Firebase Storage is not configured.');
    }
    final safeUserId = _safeSegment(userId);
    final safeFileName = _safeSegment(fileName);
    if (safeUserId.isEmpty || safeFileName.isEmpty || bytes.isEmpty) {
      throw ArgumentError('User ID, file name, and file content are required.');
    }

    final reference = FirebaseStorage.instance.ref(
      'users/$safeUserId/uploads/${DateTime.now().millisecondsSinceEpoch}_$safeFileName',
    );
    final snapshot = await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{'ownerUserId': userId.trim()},
      ),
    );
    return snapshot.ref.getDownloadURL();
  }

  String _safeSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
