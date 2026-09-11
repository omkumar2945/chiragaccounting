import 'dart:typed_data';

Future<Uint8List> readBinaryFile(String filePath) async {
  throw UnsupportedError(
    'Direct binary file-path import is not available on this platform. Use file bytes import flow.',
  );
}