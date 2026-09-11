import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/ai_workbench/services/ocr_module_api_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';

class ClientUploadsScreen extends StatefulWidget {
  final bool autoPickOnOpen;
  final bool autoRouteAfterDetect;
  final String autoRouteSource;
  final String? initialFilePath;
  final Uint8List? initialFileBytes;
  final String? initialFileName;

  const ClientUploadsScreen({
    super.key,
    this.autoPickOnOpen = false,
    this.autoRouteAfterDetect = false,
    this.autoRouteSource = 'manual',
    this.initialFilePath,
    this.initialFileBytes,
    this.initialFileName,
  });

  @override
  State<ClientUploadsScreen> createState() => _ClientUploadsScreenState();
}

class _ClientUploadsScreenState extends State<ClientUploadsScreen> {
  final InvoiceOcrService _ocrService = InvoiceOcrService();
  bool _isAnalyzing = false;
  String _status =
      'Upload invoice, payment, cheque, credit note, or debit note PDF/image files for auto detection.';
  OcrDocumentAnalysis? _analysis;
  ParsedInvoiceData? _lastParsedData;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  String _selectedFileName = 'upload';

  @override
  void initState() {
    super.initState();
    if (isUsableLocalFilePath(widget.initialFilePath)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickAndAnalyze(
          initialFilePath: widget.initialFilePath,
          initialFileName: widget.initialFileName,
        );
      });
      return;
    }

    if (widget.initialFileBytes != null &&
        widget.initialFileBytes!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickAndAnalyze(
          initialFileBytes: widget.initialFileBytes,
          initialFileName: widget.initialFileName,
        );
      });
      return;
    }

    if (widget.autoPickOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickAndAnalyze();
      });
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  String _kindLabel(OcrDocumentKind kind) {
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return 'Sales Invoice';
      case OcrDocumentKind.purchaseBill:
        return 'Purchase Bill';
      case OcrDocumentKind.creditNote:
        return 'Credit Note';
      case OcrDocumentKind.debitNote:
        return 'Debit Note';
      case OcrDocumentKind.chequeGiven:
        return 'Cheque Given';
      case OcrDocumentKind.chequeReceived:
        return 'Cheque Received';
      case OcrDocumentKind.paymentVoucher:
        return 'Payment Voucher';
      case OcrDocumentKind.receiptVoucher:
        return 'Receipt Voucher';
      case OcrDocumentKind.unknown:
        return 'Unknown';
    }
  }

  Future<void> _pickAndAnalyze({
    String? sourceLabel,
    String? initialFilePath,
    Uint8List? initialFileBytes,
    String? initialFileName,
  }) async {
    setState(() {
      _isAnalyzing = true;
      _status = sourceLabel == null
          ? 'Reading uploaded file...'
          : 'Reading uploaded $sourceLabel file...';
      _analysis = null;
    });

    try {
      String? path = initialFilePath;
      Uint8List? bytes = initialFileBytes;
      String fileName = (initialFileName ?? '').trim();
      if ((path ?? '').trim().isEmpty && (bytes == null || bytes.isEmpty)) {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          withData: true,
          allowedExtensions: [
            'pdf',
            'png',
            'jpg',
            'jpeg',
            'webp',
            'csv',
            'xlsx',
            'xls',
            'xlsm',
            'json',
            'txt',
          ],
        );
        if (result == null || result.files.isEmpty) {
          setState(() {
            _isAnalyzing = false;
            _status = 'Upload cancelled.';
          });
          return;
        }
        path = result.files.first.path;
        bytes = result.files.first.bytes;
        fileName = result.files.first.name.trim();
      }

      if (fileName.isEmpty) {
        fileName = _fileNameFromPath(path);
      }

      final extension = _fileExtension(fileName);

      if (_isSpreadsheet(extension)) {
        final spreadsheetAnalysis = const OcrDocumentAnalysis(
          kind: OcrDocumentKind.unknown,
          confidence: 0.5,
          signals: ['spreadsheet upload'],
        );
        final queueBucket = _queueBucketFor(
          analysis: spreadsheetAnalysis,
          extension: extension,
        );

        setState(() {
          _selectedFilePath = path;
          _selectedFileBytes = bytes;
          _selectedFileName = fileName;
          _analysis = spreadsheetAnalysis;
          _lastParsedData = const ParsedInvoiceData();
          _isAnalyzing = false;
          _status =
              'Spreadsheet detected. Queue: ${queueBucket.displayName}. Review destination and submit to continue.';
        });

        if (widget.autoRouteAfterDetect && mounted) {
          await _submitToAccountantQueue(spreadsheetAnalysis);
        }
        return;
      }

      if (!isUsableLocalFilePath(path) && (bytes == null || bytes.isEmpty)) {
        setState(() {
          _isAnalyzing = false;
          _status =
              'Selected file is not available as a local path on this platform.';
        });
        return;
      }

      final isPdf = extension == 'pdf';
      final isSupportChatUpload = widget.autoRouteSource == 'support-chat';
      String extractedText;
      if (isUsableLocalFilePath(path)) {
        final file = File(path!);
        extractedText = isPdf
            ? await _ocrService.extractTextFromPdf(
                file,
                maxPagesToScan: isSupportChatUpload ? 3 : 8,
                rasterDpi: isSupportChatUpload ? 170 : 220,
              )
            : await _ocrService.extractTextFromImage(file);
      } else {
        final payloadBytes = bytes!;
        extractedText = isPdf
            ? await _ocrService.extractTextFromPdfBytes(
                payloadBytes,
                maxPagesToScan: isSupportChatUpload ? 3 : 8,
                rasterDpi: isSupportChatUpload ? 170 : 220,
              )
            : await _ocrService.extractTextFromImageBytes(
                payloadBytes,
                fileName: fileName,
              );
      }
      final parsed = _ocrService.parseInvoiceText(extractedText);
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final queueBucket = _queueBucketFor(
        analysis: analysis,
        extension: extension,
      );

      setState(() {
        _selectedFilePath = path;
        _selectedFileBytes = bytes;
        _selectedFileName = fileName;
        _analysis = analysis;
        _lastParsedData = parsed;
        _isAnalyzing = false;
        _status =
            'Detected: ${_kindLabel(analysis.kind)} (${(analysis.confidence * 100).round()}%). Queue: ${queueBucket.displayName}';
      });

      if (widget.autoRouteAfterDetect && mounted) {
        await _submitToAccountantQueue(analysis);
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        if (e is UnsupportedError) {
          final message = e.message?.toString() ?? e.toString();
          _status = message.contains('scanned')
              ? 'This PDF is scanned. Desktop image OCR fallback is not available. Use Android/iOS or a text-based PDF.'
              : 'OCR image recognition is not available on this device. Use PDF upload or run on Android/iOS.';
        } else {
          _status = 'Failed to analyze upload: $e';
        }
      });
    }
  }

  Future<void> _reviewAndRoute({
    required OcrDocumentAnalysis autoDetected,
    required ParsedInvoiceData parsedData,
  }) async {
    final queueBucket = _queueBucketFor(
      analysis: autoDetected,
      extension: _fileExtension(_selectedFileName),
    );

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit to Accountant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document: ${_kindLabel(autoDetected.kind)}'),
              const SizedBox(height: 6),
              Text('Confidence: ${(autoDetected.confidence * 100).round()}%'),
              const SizedBox(height: 6),
              Text('File: $_selectedFileName'),
              const SizedBox(height: 6),
              Text('Queue: ${queueBucket.displayName}'),
              const SizedBox(height: 12),
              if (parsedData.partyName.isNotEmpty)
                Text('Party: ${parsedData.partyName}'),
              if (parsedData.billNumber.isNotEmpty)
                Text('Invoice/Bill No: ${parsedData.billNumber}'),
              if (parsedData.totalAmount > 0)
                Text('Amount: ${parsedData.totalAmount.toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Submit'),
          ),
        ],
      ),
    );

    if (!mounted || submitted != true) return;
    await _submitToAccountantQueue(autoDetected);
  }

  String _fileNameFromPath(String? path) {
    final clean = path?.trim() ?? '';
    if (clean.isEmpty) return 'upload';
    final parts = clean.split(RegExp(r'[\\/]'));
    if (parts.isEmpty) return 'upload';
    return parts.last.trim().isEmpty ? 'upload' : parts.last.trim();
  }

  String _fileExtension(String name) {
    final lower = name.toLowerCase();
    final idx = lower.lastIndexOf('.');
    if (idx <= -1 || idx >= lower.length - 1) return '';
    return lower.substring(idx + 1);
  }

  bool _isSpreadsheet(String extension) {
    return extension == 'csv' ||
        extension == 'xlsx' ||
        extension == 'xls' ||
        extension == 'xlsm' ||
        extension == 'json' ||
        extension == 'txt';
  }

  ClientBillingMode _billingMode() {
    final user = context.read<AuthController>().currentUser;
    if (user == null) {
      return ClientBillingMode.imageUploadAccountantEntry;
    }
    return context
        .read<ClientPortalAccessService>()
        .profileFor(user.id)
        .billingMode;
  }

  ClientDocumentQueueBucket _queueBucketFor({
    required OcrDocumentAnalysis analysis,
    required String extension,
  }) {
    if (_isSpreadsheet(extension)) {
      return ClientDocumentQueueBucket.import;
    }

    final isImageOnly =
        _billingMode() == ClientBillingMode.imageUploadAccountantEntry;

    switch (analysis.kind) {
      case OcrDocumentKind.salesInvoice:
        return ClientDocumentQueueBucket.sales;
      case OcrDocumentKind.purchaseBill:
        return isImageOnly
            ? ClientDocumentQueueBucket.expense
            : ClientDocumentQueueBucket.purchase;
      case OcrDocumentKind.creditNote:
        return ClientDocumentQueueBucket.creditNote;
      case OcrDocumentKind.debitNote:
        return ClientDocumentQueueBucket.debitNote;
      case OcrDocumentKind.chequeGiven:
      case OcrDocumentKind.paymentVoucher:
        return ClientDocumentQueueBucket.payment;
      case OcrDocumentKind.chequeReceived:
      case OcrDocumentKind.receiptVoucher:
        return ClientDocumentQueueBucket.receipt;
      case OcrDocumentKind.unknown:
        final lower = _selectedFileName.toLowerCase();
        if (lower.contains('bank') || lower.contains('statement')) {
          return ClientDocumentQueueBucket.bank;
        }
        return ClientDocumentQueueBucket.review;
    }
  }

  Future<void> _submitToAccountantQueue(
    OcrDocumentAnalysis? autoDetected,
  ) async {
    final fileName = _selectedFileName.trim();
    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file selected to submit to accountant queue.'),
        ),
      );
      return;
    }

    final auth = context.read<AuthController>();
    final userId = auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client session is not available.')),
      );
      return;
    }
    final assignedAccountantId = context
        .read<AdminUserService>()
        .accountingAccessFor(userId)
        .assignedAccountantId
        .trim();
    if (assignedAccountantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No accountant is assigned. Ask your CA firm to assign one first.',
          ),
        ),
      );
      return;
    }
    final extension = _fileExtension(fileName);
    final queueBucket = _queueBucketFor(
      analysis:
          autoDetected ??
          _analysis ??
          const OcrDocumentAnalysis(
            kind: OcrDocumentKind.unknown,
            confidence: 0,
          ),
      extension: extension,
    );

    Uint8List? uploadBytes = _selectedFileBytes;
    if ((uploadBytes == null || uploadBytes.isEmpty) &&
        isUsableLocalFilePath(_selectedFilePath)) {
      uploadBytes = await File(_selectedFilePath!).readAsBytes();
    }
    final ocrApi = OcrModuleApiService();
    String? remoteDocumentId;
    try {
      if (ocrApi.isConfigured) {
        if (uploadBytes == null || uploadBytes.isEmpty) {
          throw const FormatException('Selected file data is unavailable.');
        }
        remoteDocumentId = await ocrApi.upload(
          clientId: userId,
          assignedAccountantId: assignedAccountantId,
          fileName: fileName,
          bytes: uploadBytes,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR service upload failed: $error')),
      );
      return;
    }

    final job = await context.read<WorkbenchQueueService>().addJob(
      fileName: fileName,
      filePath: _selectedFilePath,
      fileBytes: uploadBytes,
      autoProcess: true,
      clientId: userId,
      assignedAccountantId: assignedAccountantId,
      remoteDocumentId: remoteDocumentId,
      queueBucket: queueBucket,
      intakeChannel: widget.autoRouteSource == 'support-chat'
          ? ClientDocumentIntakeChannel.whatsapp
          : ClientDocumentIntakeChannel.mobileApp,
      sourceIdentity: widget.autoRouteSource,
    );

    if (!mounted) return;
    setState(() {
      _status =
          'Uploaded and queued for accountant. Ref: ${job.externalReference ?? job.id}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Document saved. Accountant queue updated with AI auto-detection.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Uploads'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto Detection Upload',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _pickAndAnalyze,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload PDF/Image & Detect'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isAnalyzing
                              ? null
                              : () =>
                                    _pickAndAnalyze(sourceLabel: 'credit note'),
                          icon: const Icon(Icons.note_outlined),
                          label: const Text('Credit Note Upload'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isAnalyzing
                              ? null
                              : () =>
                                    _pickAndAnalyze(sourceLabel: 'debit note'),
                          icon: const Icon(Icons.note_alt_outlined),
                          label: const Text('Debit Note Upload'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _analysis == null
                              ? null
                              : () => _reviewAndRoute(
                                  autoDetected: _analysis!,
                                  parsedData:
                                      _lastParsedData ??
                                      const ParsedInvoiceData(),
                                ),
                          icon: const Icon(Icons.alt_route_outlined),
                          label: const Text('Review & Open Suggested Module'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Supported detections: Sales, Purchase, Credit Note, Debit Note, Cheque Given/Received, Payment/Receipt Voucher. PDF and image uploads are supported.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
