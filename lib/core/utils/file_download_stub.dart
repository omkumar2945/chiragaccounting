import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> downloadFile({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  final savedPath = await FilePicker.saveFile(
    dialogTitle: 'Save file',
    fileName: fileName,
    bytes: bytes,
  );
  return savedPath != null;
}
