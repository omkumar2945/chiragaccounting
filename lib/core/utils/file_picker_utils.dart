bool isUsableLocalFilePath(String? path) {
  final trimmed = path?.trim() ?? '';
  if (trimmed.isEmpty) return false;
  return !trimmed.startsWith('blob:') && !trimmed.startsWith('data:');
}
