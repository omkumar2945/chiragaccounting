import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:chirag_accounting/features/billing_print_setup/models/billing_print_setup_models.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';

class BillingPrintSetupService extends ChangeNotifier {
  final List<BillingProfile> _profiles = <BillingProfile>[];
  final List<BillingChangeRequest> _changeRequests = <BillingChangeRequest>[];

  List<BillingProfile> get profiles => List.unmodifiable(_profiles);
  List<BillingChangeRequest> get changeRequests =>
      List.unmodifiable(_changeRequests);

  List<BillingProfile> profilesByStatus(BillingProfileStatus? status) {
    if (status == null) return profiles;
    return _profiles
        .where((profile) => profile.status == status)
        .toList(growable: false);
  }

  List<BillingProfile> searchProfiles(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return profiles;
    return _profiles.where((profile) {
      return profile.clientName.toLowerCase().contains(q) ||
          profile.clientId.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  BillingProfile? forClient(String clientId) {
    try {
      return _profiles.firstWhere((profile) => profile.clientId == clientId);
    } catch (_) {
      return null;
    }
  }

  BillingProfile createProfile({
    required String clientId,
    required String clientName,
    required String createdBy,
    required BillingBusinessType businessType,
    required InvoicePrintFormat format,
  }) {
    final id = 'bp-${DateTime.now().microsecondsSinceEpoch}';
    final template = InvoiceTemplateVersion(
      id: 'tmpl-$id-v1',
      version: 1,
      format: format,
      logoPath: '',
      footerText: 'Thank you for your business.',
      fieldVisibility: const <String, bool>{
        'gstin': true,
        'pan': true,
        'shippingAddress': true,
        'terms': true,
      },
      columnVisibility: const <String, bool>{
        'hsn': true,
        'discount': true,
        'gst': true,
      },
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    final paper = _paperFromFormat(format);
    final defaultPrinter = PrintProfile(
      id: 'pp-$id-v1',
      profileName: 'Default Printer',
      printerType: _printerTypeFromFormat(format),
      printerName: 'Not configured',
      paperProfile: paper,
      isDefault: true,
    );
    final profileVersion = BillingProfileVersion(
      id: 'bpv-$id-v1',
      profileId: id,
      version: 1,
      status: BillingProfileStatus.draft,
      businessType: businessType,
      invoiceFormat: format,
      templateVersionId: template.id,
      defaultPrintProfileId: defaultPrinter.id,
      approvedAt: null,
      approvedBy: '',
      changeReason: '',
    );
    final profile = BillingProfile(
      id: id,
      clientId: clientId,
      clientName: clientName,
      status: BillingProfileStatus.draft,
      businessType: businessType,
      invoiceFormat: format,
      version: 1,
      printProfiles: <PrintProfile>[defaultPrinter],
      templateVersions: <InvoiceTemplateVersion>[template],
      profileVersions: <BillingProfileVersion>[profileVersion],
      createdAt: DateTime.now(),
      createdBy: createdBy,
      locked: false,
    );
    _profiles.add(profile);
    notifyListeners();
    return profile;
  }

  BillingChangeRequest requestChange({
    required String profileId,
    required String requestedBy,
    required String reason,
    required InvoicePrintFormat requestedFormat,
  }) {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index < 0) {
      throw StateError('Billing profile not found.');
    }

    final request = BillingChangeRequest(
      id: 'bcr-${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      requestedBy: requestedBy,
      reason: reason,
      requestedFormat: requestedFormat,
      status: BillingProfileStatus.pendingApproval,
      requestedAt: DateTime.now(),
      reviewedBy: '',
      reviewedAt: null,
    );
    _changeRequests.add(request);

    _profiles[index] = _profiles[index].copyWith(
      status: BillingProfileStatus.changeRequested,
    );
    notifyListeners();
    return request;
  }

  void approveChange({
    required String requestId,
    required String approvedBy,
  }) {
    final reqIndex = _changeRequests.indexWhere((request) => request.id == requestId);
    if (reqIndex < 0) throw StateError('Change request not found.');

    final request = _changeRequests[reqIndex];
    final profileIndex = _profiles.indexWhere((profile) => profile.id == request.profileId);
    if (profileIndex < 0) throw StateError('Billing profile not found.');

    final oldProfile = _profiles[profileIndex];
    final nextVersion = oldProfile.version + 1;

    final template = InvoiceTemplateVersion(
      id: 'tmpl-${oldProfile.id}-v$nextVersion',
      version: nextVersion,
      format: request.requestedFormat,
      logoPath: oldProfile.templateVersions.last.logoPath,
      footerText: oldProfile.templateVersions.last.footerText,
      fieldVisibility: oldProfile.templateVersions.last.fieldVisibility,
      columnVisibility: oldProfile.templateVersions.last.columnVisibility,
      createdAt: DateTime.now(),
      createdBy: approvedBy,
    );

    final newDefaultPrinter = oldProfile.defaultPrintProfile?.copyWith(isDefault: true) ??
        PrintProfile(
          id: 'pp-${oldProfile.id}-v$nextVersion',
          profileName: 'Default Printer',
          printerType: _printerTypeFromFormat(request.requestedFormat),
          printerName: 'Not configured',
          paperProfile: _paperFromFormat(request.requestedFormat),
          isDefault: true,
        );

    final version = BillingProfileVersion(
      id: 'bpv-${oldProfile.id}-v$nextVersion',
      profileId: oldProfile.id,
      version: nextVersion,
      status: BillingProfileStatus.approved,
      businessType: oldProfile.businessType,
      invoiceFormat: request.requestedFormat,
      templateVersionId: template.id,
      defaultPrintProfileId: newDefaultPrinter.id,
      approvedAt: DateTime.now(),
      approvedBy: approvedBy,
      changeReason: request.reason,
    );

    _profiles[profileIndex] = oldProfile.copyWith(
      status: BillingProfileStatus.locked,
      invoiceFormat: request.requestedFormat,
      version: nextVersion,
      locked: true,
      templateVersions: <InvoiceTemplateVersion>[...oldProfile.templateVersions, template],
      profileVersions: <BillingProfileVersion>[...oldProfile.profileVersions, version],
      printProfiles: _normalizeDefaultPrinter(oldProfile.printProfiles, newDefaultPrinter),
    );

    _changeRequests[reqIndex] = BillingChangeRequest(
      id: request.id,
      profileId: request.profileId,
      requestedBy: request.requestedBy,
      reason: request.reason,
      requestedFormat: request.requestedFormat,
      status: BillingProfileStatus.approved,
      requestedAt: request.requestedAt,
      reviewedBy: approvedBy,
      reviewedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void rejectChange({
    required String requestId,
    required String rejectedBy,
  }) {
    final reqIndex = _changeRequests.indexWhere((request) => request.id == requestId);
    if (reqIndex < 0) throw StateError('Change request not found.');

    final request = _changeRequests[reqIndex];
    final profileIndex = _profiles.indexWhere((profile) => profile.id == request.profileId);
    if (profileIndex >= 0) {
      _profiles[profileIndex] = _profiles[profileIndex].copyWith(
        status: BillingProfileStatus.locked,
      );
    }

    _changeRequests[reqIndex] = BillingChangeRequest(
      id: request.id,
      profileId: request.profileId,
      requestedBy: request.requestedBy,
      reason: request.reason,
      requestedFormat: request.requestedFormat,
      status: BillingProfileStatus.rejected,
      requestedAt: request.requestedAt,
      reviewedBy: rejectedBy,
      reviewedAt: DateTime.now(),
    );
    notifyListeners();
  }

  InvoicePrintResolution? resolveForInvoice(SalesInvoice invoice) {
    final profile = forClient(invoice.customerName);
    if (profile == null || profile.profileVersions.isEmpty) return null;

    final version = profile.profileVersions.last;
    final printProfile = profile.printProfiles
        .where((p) => p.id == version.defaultPrintProfileId)
        .firstOrNull ??
        profile.defaultPrintProfile;
    if (printProfile == null) return null;

    return InvoicePrintResolution(
      profileId: profile.id,
      profileVersionId: version.id,
      templateVersionId: version.templateVersionId,
      printProfileId: printProfile.id,
      format: version.invoiceFormat,
      paper: printProfile.paperProfile,
    );
  }

  Future<Uint8List> renderInvoicePdf(
    SalesInvoice invoice, {
    required InvoicePrintResolution resolution,
  }) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final g = page.graphics;

    final title = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final body = PdfStandardFont(PdfFontFamily.helvetica, 9);

    g.drawString('INVOICE (${describeEnum(resolution.format)})', title, bounds: const Rect.fromLTWH(0, 0, 500, 20));
    g.drawString('Invoice: ${invoice.invoiceNumber}', body, bounds: const Rect.fromLTWH(0, 28, 250, 16));
    g.drawString('Customer: ${invoice.customerName}', body, bounds: const Rect.fromLTWH(0, 44, 400, 16));
    g.drawString('Total: Rs ${invoice.grandTotal.toStringAsFixed(2)}', body, bounds: const Rect.fromLTWH(0, 60, 250, 16));
    g.drawString('Profile Version: ${resolution.profileVersionId}', body, bounds: const Rect.fromLTWH(0, 76, 300, 16));

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  List<PrintProfile> _normalizeDefaultPrinter(
    List<PrintProfile> profiles,
    PrintProfile target,
  ) {
    final found = profiles.any((profile) => profile.id == target.id);
    final mapped = profiles
        .map((profile) => profile.copyWith(isDefault: profile.id == target.id))
        .toList(growable: true);
    if (!found) {
      mapped.add(target.copyWith(isDefault: true));
    }
    return mapped;
  }

  PaperProfile _paperFromFormat(InvoicePrintFormat format) {
    switch (format) {
      case InvoicePrintFormat.a4Full:
      case InvoicePrintFormat.a4Compact:
        return const PaperProfile(preset: PaperPreset.a4);
      case InvoicePrintFormat.a5:
        return const PaperProfile(preset: PaperPreset.a5);
      case InvoicePrintFormat.thermal58:
      case InvoicePrintFormat.posEdc:
        return const PaperProfile(preset: PaperPreset.mm58, widthMm: 58);
      case InvoicePrintFormat.thermal80:
      case InvoicePrintFormat.smallBill:
        return const PaperProfile(preset: PaperPreset.mm80, widthMm: 80);
      case InvoicePrintFormat.label:
        return const PaperProfile(preset: PaperPreset.custom, widthMm: 100, heightMm: 50);
      case InvoicePrintFormat.custom:
        return const PaperProfile(preset: PaperPreset.custom, widthMm: 210, heightMm: 297);
    }
  }

  String _printerTypeFromFormat(InvoicePrintFormat format) {
    switch (format) {
      case InvoicePrintFormat.thermal58:
      case InvoicePrintFormat.thermal80:
      case InvoicePrintFormat.posEdc:
      case InvoicePrintFormat.smallBill:
        return 'Thermal';
      case InvoicePrintFormat.label:
        return 'Label Printer';
      default:
        return 'A4/A5';
    }
  }
}
