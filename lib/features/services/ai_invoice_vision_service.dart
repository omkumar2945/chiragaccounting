import 'dart:typed_data';

class AiInvoiceVisionPayload {
  const AiInvoiceVisionPayload({
    required this.json,
    this.modelText = '',
  });

  final Map<String, dynamic> json;
  final String modelText;
}

class AiInvoiceVisionService {
  Future<AiInvoiceVisionPayload?> readInvoice(
    Uint8List bytes, {
    required String fileName,
  }) async {
    // Fallback stub: this workspace can run without a cloud vision provider.
    return null;
  }
}
