import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readBinaryFile(String filePath) {
  return File(filePath).readAsBytes();
}