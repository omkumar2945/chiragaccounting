enum BillingProfileStatus {
  draft,
  pendingApproval,
  approved,
  active,
  locked,
  changeRequested,
  rejected,
}

enum BillingBusinessType {
  retail,
  textile,
  readymade,
  hotel,
  restaurant,
  wholesale,
  manufacturing,
  service,
  other,
}

enum InvoicePrintFormat {
  a4Full,
  a4Compact,
  a5,
  thermal80,
  thermal58,
  posEdc,
  smallBill,
  label,
  custom,
}

enum PaperPreset {
  a4,
  a5,
  mm58,
  mm80,
  custom,
}

class PaperProfile {
  const PaperProfile({
    required this.preset,
    this.widthMm,
    this.heightMm,
    this.marginTopMm = 4,
    this.marginBottomMm = 4,
    this.marginLeftMm = 4,
    this.marginRightMm = 4,
  });

  final PaperPreset preset;
  final double? widthMm;
  final double? heightMm;
  final double marginTopMm;
  final double marginBottomMm;
  final double marginLeftMm;
  final double marginRightMm;
}

class PrintProfile {
  const PrintProfile({
    required this.id,
    required this.profileName,
    required this.printerType,
    required this.printerName,
    required this.paperProfile,
    this.copies = 1,
    this.autoCut = false,
    this.autoPrint = false,
    this.isDefault = false,
  });

  final String id;
  final String profileName;
  final String printerType;
  final String printerName;
  final PaperProfile paperProfile;
  final int copies;
  final bool autoCut;
  final bool autoPrint;
  final bool isDefault;

  PrintProfile copyWith({
    bool? isDefault,
    int? copies,
  }) => PrintProfile(
    id: id,
    profileName: profileName,
    printerType: printerType,
    printerName: printerName,
    paperProfile: paperProfile,
    copies: copies ?? this.copies,
    autoCut: autoCut,
    autoPrint: autoPrint,
    isDefault: isDefault ?? this.isDefault,
  );
}

class InvoiceTemplateVersion {
  const InvoiceTemplateVersion({
    required this.id,
    required this.version,
    required this.format,
    required this.logoPath,
    required this.footerText,
    required this.fieldVisibility,
    required this.columnVisibility,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final int version;
  final InvoicePrintFormat format;
  final String logoPath;
  final String footerText;
  final Map<String, bool> fieldVisibility;
  final Map<String, bool> columnVisibility;
  final DateTime createdAt;
  final String createdBy;
}

class BillingProfileVersion {
  const BillingProfileVersion({
    required this.id,
    required this.profileId,
    required this.version,
    required this.status,
    required this.businessType,
    required this.invoiceFormat,
    required this.templateVersionId,
    required this.defaultPrintProfileId,
    required this.approvedAt,
    required this.approvedBy,
    required this.changeReason,
  });

  final String id;
  final String profileId;
  final int version;
  final BillingProfileStatus status;
  final BillingBusinessType businessType;
  final InvoicePrintFormat invoiceFormat;
  final String templateVersionId;
  final String defaultPrintProfileId;
  final DateTime? approvedAt;
  final String approvedBy;
  final String changeReason;
}

class BillingProfile {
  const BillingProfile({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.businessType,
    required this.invoiceFormat,
    required this.version,
    required this.printProfiles,
    required this.templateVersions,
    required this.profileVersions,
    required this.createdAt,
    required this.createdBy,
    required this.locked,
  });

  final String id;
  final String clientId;
  final String clientName;
  final BillingProfileStatus status;
  final BillingBusinessType businessType;
  final InvoicePrintFormat invoiceFormat;
  final int version;
  final List<PrintProfile> printProfiles;
  final List<InvoiceTemplateVersion> templateVersions;
  final List<BillingProfileVersion> profileVersions;
  final DateTime createdAt;
  final String createdBy;
  final bool locked;

  PrintProfile? get defaultPrintProfile =>
      printProfiles.where((p) => p.isDefault).firstOrNull;

  BillingProfile copyWith({
    BillingProfileStatus? status,
    BillingBusinessType? businessType,
    InvoicePrintFormat? invoiceFormat,
    int? version,
    List<PrintProfile>? printProfiles,
    List<InvoiceTemplateVersion>? templateVersions,
    List<BillingProfileVersion>? profileVersions,
    bool? locked,
  }) => BillingProfile(
    id: id,
    clientId: clientId,
    clientName: clientName,
    status: status ?? this.status,
    businessType: businessType ?? this.businessType,
    invoiceFormat: invoiceFormat ?? this.invoiceFormat,
    version: version ?? this.version,
    printProfiles: printProfiles ?? this.printProfiles,
    templateVersions: templateVersions ?? this.templateVersions,
    profileVersions: profileVersions ?? this.profileVersions,
    createdAt: createdAt,
    createdBy: createdBy,
    locked: locked ?? this.locked,
  );
}

class BillingChangeRequest {
  const BillingChangeRequest({
    required this.id,
    required this.profileId,
    required this.requestedBy,
    required this.reason,
    required this.requestedFormat,
    required this.status,
    required this.requestedAt,
    required this.reviewedBy,
    required this.reviewedAt,
  });

  final String id;
  final String profileId;
  final String requestedBy;
  final String reason;
  final InvoicePrintFormat requestedFormat;
  final BillingProfileStatus status;
  final DateTime requestedAt;
  final String reviewedBy;
  final DateTime? reviewedAt;
}

class InvoicePrintResolution {
  const InvoicePrintResolution({
    required this.profileId,
    required this.profileVersionId,
    required this.templateVersionId,
    required this.printProfileId,
    required this.format,
    required this.paper,
  });

  final String profileId;
  final String profileVersionId;
  final String templateVersionId;
  final String printProfileId;
  final InvoicePrintFormat format;
  final PaperProfile paper;
}
