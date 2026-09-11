import 'package:chirag_accounting/features/roles/models/role_model.dart';

enum AppModule {
  dashboard,
  sales,
  purchase,
  referral,
  chat,
  uploads,
  accounting,
  banking,
  gst,
  reports,
  users,
  settings,
  customers,
  products,
}

extension AppModuleExtension on AppModule {
  String get displayName {
    switch (this) {
      case AppModule.dashboard:
        return 'Dashboard';
      case AppModule.sales:
        return 'Sales';
      case AppModule.purchase:
        return 'Purchase';
      case AppModule.referral:
        return 'Referral Rewards';
      case AppModule.chat:
        return 'Chat';
      case AppModule.uploads:
        return 'Uploads';
      case AppModule.accounting:
        return 'Accounting';
      case AppModule.banking:
        return 'Banking';
      case AppModule.gst:
        return 'GST';
      case AppModule.reports:
        return 'Reports';
      case AppModule.users:
        return 'Users';
      case AppModule.settings:
        return 'Settings';
      case AppModule.customers:
        return 'Customers';
      case AppModule.products:
        return 'Products';
    }
  }
}

enum PermissionLevel { none, view, limited, full }

enum BankingPermission {
  createPaymentVoucher,
  createReceiptVoucher,
  createCreditNoteVoucher,
  createDebitNoteVoucher,
  viewBalance,
  viewStatements,
  uploadStatements,
  uploadPaymentProof,
  uploadChequeImages,
  viewPaymentHistory,
  autoEntrySystem,
}

enum ReportPermission {
  allReports,
  salesReport,
  purchaseReport,
  gstReport,
  outstandingReport,
  profitAndLoss,
  balanceSheet,
  trialBalance,
  cashBook,
  bankBook,
  customerLedger,
  vendorLedger,
  generalLedger,
}

extension BankingPermissionExtension on BankingPermission {
  String get displayName {
    switch (this) {
      case BankingPermission.createPaymentVoucher:
        return 'Payment Voucher';
      case BankingPermission.createReceiptVoucher:
        return 'Receipt Voucher';
      case BankingPermission.createCreditNoteVoucher:
        return 'Credit Note Voucher';
      case BankingPermission.createDebitNoteVoucher:
        return 'Debit Note Voucher';
      case BankingPermission.viewBalance:
        return 'View Balance';
      case BankingPermission.viewStatements:
        return 'View Statements';
      case BankingPermission.uploadStatements:
        return 'Upload Statements';
      case BankingPermission.uploadPaymentProof:
        return 'Upload Payment Proof';
      case BankingPermission.uploadChequeImages:
        return 'Upload Cheque Images';
      case BankingPermission.viewPaymentHistory:
        return 'View Payment History';
      case BankingPermission.autoEntrySystem:
        return 'Autoentry System';
    }
  }
}

extension ReportPermissionExtension on ReportPermission {
  String get displayName {
    switch (this) {
      case ReportPermission.allReports:
        return 'All Reports';
      case ReportPermission.salesReport:
        return 'Sales Report';
      case ReportPermission.purchaseReport:
        return 'Purchase Report';
      case ReportPermission.gstReport:
        return 'GST Report';
      case ReportPermission.outstandingReport:
        return 'Outstanding Report';
      case ReportPermission.profitAndLoss:
        return 'Profit & Loss';
      case ReportPermission.balanceSheet:
        return 'Balance Sheet';
      case ReportPermission.trialBalance:
        return 'Trial Balance';
      case ReportPermission.cashBook:
        return 'Cash Book';
      case ReportPermission.bankBook:
        return 'Bank Book';
      case ReportPermission.customerLedger:
        return 'Customer Ledger';
      case ReportPermission.vendorLedger:
        return 'Vendor Ledger';
      case ReportPermission.generalLedger:
        return 'General Ledger';
    }
  }
}

class PermissionMatrix {
  static const Map<UserRole, Map<AppModule, PermissionLevel>> matrix = {
    UserRole.superAdmin: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.full,
      AppModule.banking: PermissionLevel.full,
      AppModule.gst: PermissionLevel.full,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.full,
      AppModule.settings: PermissionLevel.full,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.admin: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.full,
      AppModule.banking: PermissionLevel.full,
      AppModule.gst: PermissionLevel.full,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.full,
      AppModule.settings: PermissionLevel.full,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.partner: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.full,
      AppModule.banking: PermissionLevel.full,
      AppModule.gst: PermissionLevel.full,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.view,
      AppModule.settings: PermissionLevel.view,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.manager: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.view,
      AppModule.banking: PermissionLevel.view,
      AppModule.gst: PermissionLevel.view,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.none,
      AppModule.settings: PermissionLevel.none,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.firmAdmin: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.full,
      AppModule.banking: PermissionLevel.full,
      AppModule.gst: PermissionLevel.full,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.full,
      AppModule.settings: PermissionLevel.full,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.businessOwner: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.full,
      AppModule.banking: PermissionLevel.full,
      AppModule.gst: PermissionLevel.full,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.none,
      AppModule.settings: PermissionLevel.limited,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.accountant: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.full,
      AppModule.chat: PermissionLevel.full,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.full,
      AppModule.banking: PermissionLevel.full,
      AppModule.gst: PermissionLevel.full,
      AppModule.reports: PermissionLevel.full,
      AppModule.users: PermissionLevel.none,
      AppModule.settings: PermissionLevel.none,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.dataEntryOperator: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.full,
      AppModule.purchase: PermissionLevel.full,
      AppModule.referral: PermissionLevel.none,
      AppModule.chat: PermissionLevel.none,
      AppModule.uploads: PermissionLevel.full,
      AppModule.accounting: PermissionLevel.none,
      AppModule.banking: PermissionLevel.none,
      AppModule.gst: PermissionLevel.none,
      AppModule.reports: PermissionLevel.none,
      AppModule.users: PermissionLevel.none,
      AppModule.settings: PermissionLevel.none,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
    UserRole.checker: {
      AppModule.dashboard: PermissionLevel.full,
      AppModule.sales: PermissionLevel.view,
      AppModule.purchase: PermissionLevel.view,
      AppModule.referral: PermissionLevel.view,
      AppModule.chat: PermissionLevel.view,
      AppModule.uploads: PermissionLevel.view,
      AppModule.accounting: PermissionLevel.view,
      AppModule.banking: PermissionLevel.view,
      AppModule.gst: PermissionLevel.view,
      AppModule.reports: PermissionLevel.view,
      AppModule.users: PermissionLevel.none,
      AppModule.settings: PermissionLevel.none,
      AppModule.customers: PermissionLevel.view,
      AppModule.products: PermissionLevel.view,
    },
    UserRole.client: {
      AppModule.dashboard: PermissionLevel.view,
      AppModule.sales: PermissionLevel.view,
      AppModule.purchase: PermissionLevel.view,
      AppModule.referral: PermissionLevel.view,
      AppModule.chat: PermissionLevel.view,
      AppModule.uploads: PermissionLevel.view,
      AppModule.accounting: PermissionLevel.view,
      AppModule.banking: PermissionLevel.view,
      AppModule.gst: PermissionLevel.view,
      AppModule.reports: PermissionLevel.limited,
      AppModule.users: PermissionLevel.none,
      AppModule.settings: PermissionLevel.none,
      AppModule.customers: PermissionLevel.full,
      AppModule.products: PermissionLevel.full,
    },
  };

  static const Set<BankingPermission> _fullBankingPermissions = {
    BankingPermission.createPaymentVoucher,
    BankingPermission.createReceiptVoucher,
    BankingPermission.createCreditNoteVoucher,
    BankingPermission.createDebitNoteVoucher,
    BankingPermission.viewBalance,
    BankingPermission.viewStatements,
    BankingPermission.uploadStatements,
    BankingPermission.uploadPaymentProof,
    BankingPermission.uploadChequeImages,
    BankingPermission.viewPaymentHistory,
    BankingPermission.autoEntrySystem,
  };

  static const Set<BankingPermission> _viewBankingPermissions = {
    BankingPermission.createPaymentVoucher,
    BankingPermission.createReceiptVoucher,
    BankingPermission.createCreditNoteVoucher,
    BankingPermission.createDebitNoteVoucher,
    BankingPermission.viewBalance,
    BankingPermission.viewStatements,
    BankingPermission.uploadStatements,
    BankingPermission.uploadPaymentProof,
    BankingPermission.uploadChequeImages,
    BankingPermission.viewPaymentHistory,
    BankingPermission.autoEntrySystem,
  };

  static const Set<ReportPermission> _fullReportPermissions = {
    ReportPermission.allReports,
    ReportPermission.salesReport,
    ReportPermission.purchaseReport,
    ReportPermission.gstReport,
    ReportPermission.outstandingReport,
    ReportPermission.profitAndLoss,
    ReportPermission.balanceSheet,
    ReportPermission.trialBalance,
    ReportPermission.cashBook,
    ReportPermission.bankBook,
    ReportPermission.customerLedger,
    ReportPermission.vendorLedger,
    ReportPermission.generalLedger,
  };

  static const Set<ReportPermission> _viewReportPermissions = {
    ReportPermission.allReports,
    ReportPermission.salesReport,
    ReportPermission.purchaseReport,
    ReportPermission.gstReport,
    ReportPermission.outstandingReport,
    ReportPermission.profitAndLoss,
    ReportPermission.balanceSheet,
    ReportPermission.trialBalance,
    ReportPermission.cashBook,
    ReportPermission.bankBook,
    ReportPermission.customerLedger,
    ReportPermission.vendorLedger,
    ReportPermission.generalLedger,
  };

  static const Map<UserRole, Set<BankingPermission>> bankingMatrix = {
    UserRole.superAdmin: _fullBankingPermissions,
    UserRole.admin: _fullBankingPermissions,
    UserRole.partner: _fullBankingPermissions,
    UserRole.manager: _viewBankingPermissions,
    UserRole.firmAdmin: _fullBankingPermissions,
    UserRole.businessOwner: _fullBankingPermissions,
    UserRole.accountant: _fullBankingPermissions,
    UserRole.dataEntryOperator: <BankingPermission>{},
    UserRole.checker: _viewBankingPermissions,
    UserRole.client: _viewBankingPermissions,
  };

  static const Map<UserRole, Set<ReportPermission>> reportMatrix = {
    UserRole.superAdmin: _fullReportPermissions,
    UserRole.admin: _fullReportPermissions,
    UserRole.partner: _fullReportPermissions,
    UserRole.manager: _fullReportPermissions,
    UserRole.firmAdmin: _fullReportPermissions,
    UserRole.businessOwner: _fullReportPermissions,
    UserRole.accountant: _fullReportPermissions,
    UserRole.dataEntryOperator: <ReportPermission>{},
    UserRole.checker: _viewReportPermissions,
    UserRole.client: _viewReportPermissions,
  };

  static PermissionLevel getPermission(UserRole role, AppModule module) =>
      matrix[role]?[module] ?? PermissionLevel.none;

  static bool canAccess(UserRole role, AppModule module) =>
      getPermission(role, module) != PermissionLevel.none;

  static bool canEdit(UserRole role, AppModule module) {
    final level = getPermission(role, module);
    return level == PermissionLevel.full || level == PermissionLevel.limited;
  }

  static bool hasFullAccess(UserRole role, AppModule module) =>
      getPermission(role, module) == PermissionLevel.full;

  static Set<BankingPermission> getBankingPermissions(UserRole role) =>
      bankingMatrix[role] ?? const <BankingPermission>{};

  static bool hasBankingPermission(
    UserRole role,
    BankingPermission permission,
  ) => getBankingPermissions(role).contains(permission);

  static Set<ReportPermission> getReportPermissions(UserRole role) =>
      reportMatrix[role] ?? const <ReportPermission>{};

  static bool hasReportPermission(UserRole role, ReportPermission permission) =>
      getReportPermissions(role).contains(permission);
}
