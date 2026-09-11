enum UserRole {
  superAdmin,
  admin,
  partner,
  manager,
  firmAdmin,
  businessOwner,
  accountant,
  dataEntryOperator,
  checker,
  client;

  bool get isStaff => this != UserRole.client && this != UserRole.businessOwner;
  bool get isBusinessOwner => this == UserRole.businessOwner;
  bool get isClient => this == UserRole.client;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.partner:
        return 'Partner';
      case UserRole.manager:
        return 'Manager';
      case UserRole.firmAdmin:
        return 'Firm Admin';
      case UserRole.businessOwner:
        return 'Business Owner';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.dataEntryOperator:
        return 'Data Entry Operator';
      case UserRole.checker:
        return 'Checker';
      case UserRole.client:
        return 'Client';
    }
  }

  String get description {
    switch (this) {
      case UserRole.superAdmin:
        return 'Full system access, manage all firms';
      case UserRole.admin:
        return 'Manage CA firm operations and staff';
      case UserRole.partner:
        return 'Leadership access with approvals and insights';
      case UserRole.manager:
        return 'Team operations, reviews, and workflow control';
      case UserRole.firmAdmin:
        return 'Full firm access, user management';
      case UserRole.businessOwner:
        return 'Own business account with full company access';
      case UserRole.accountant:
        return 'Manage accounts, invoices, GST';
      case UserRole.dataEntryOperator:
        return 'Sales, Purchase & Customer entry';
      case UserRole.checker:
        return 'Verify and approve entries';
      case UserRole.client:
        return 'Upload bills, view reports';
    }
  }
}
