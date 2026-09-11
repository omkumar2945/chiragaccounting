import 'dart:io';

Future<String> readTextFile(String filePath) {
  return File(filePath).readAsString();
}
