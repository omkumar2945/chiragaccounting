export interface AuthoritativeClientData {
  client: {
    id: string;
    name: string;
    email: string;
    mobile: string;
    firmName: string;
    role: string;
    accountOrigin: string;
    clientStatus: string;
    loginStatus: string;
    isActive: boolean;
    mustChangePassword: boolean;
    version?: number | null;
    createdAt: string;
    lastLoginAt: string | null;
  };
  profile: {
    legalName: string;
    gstin: string;
    pan: string;
    aadhaar: string;
    address: string;
    city: string;
    state: string;
    pincode: string;
    country: string;
    registeredLocation: Record<string, unknown> | null;
    logoFileName: string;
    logoDataBase64: string;
    invoiceFormat: string;
    documentMetadata: Record<string, unknown> | null;
    lastUpdatedAt: string | null;
    version: number | null;
  };
  compliance: {
    gstRegistrationType: string;
    accountingEnabled: boolean;
    gstEnabled: boolean;
    services: unknown[];
    servicePeriods: unknown[];
    version: number | null;
  };
  assignment: {
    accountantUserId: string | null;
    caUserId: string | null;
    oldAccountingApproved: boolean;
    reportsPublished: boolean;
    auditEnabled: boolean;
    financialStatementsEnabled: boolean;
    reportSigningEnabled: boolean;
    bankProjectReportsEnabled: boolean;
    staffDelegationEnabled: boolean;
    version: number | null;
  };
  access: {
    loginEnabled: boolean;
    mobileLoginEnabled: boolean;
    webLoginEnabled: boolean;
    twoFactorRequired: boolean;
    accountLocked: boolean;
    subscriptionPlan: string;
    billingMode: string;
    accountingMode: string;
    purchaseEntryMode: string;
    salesEntryMode: string;
    modules: Record<string, unknown>;
    dashboardWidgets: Record<string, unknown>;
    documentHubAccess: Record<string, unknown>;
    version: number | null;
  };
  workspace: {
    client360Enabled: boolean;
    documentFolderEnabled: boolean;
    complianceWorkspaceEnabled: boolean;
    accountingWorkspaceEnabled: boolean;
    aiWorkspaceEnabled: boolean;
    notificationSettingsEnabled: boolean;
    version: number | null;
  };
}

const adminRoles = new Set(['super_admin', 'admin', 'manager']);

export function clientDataForRole(role: string, data: AuthoritativeClientData) {
  if (adminRoles.has(role)) return data;

  const client = {
    id: data.client.id,
    name: data.client.name,
    email: data.client.email,
    mobile: data.client.mobile,
    firmName: data.client.firmName,
  };
  if (role === 'client') {
    return {
      client,
      profile: data.profile,
      compliance: data.compliance,
      access: clientAccess(data.access),
      workspace: data.workspace,
    };
  }

  return {
    client,
    profile: {
      legalName: data.profile.legalName,
      gstin: data.profile.gstin,
      pan: data.profile.pan,
      address: data.profile.address,
      city: data.profile.city,
      state: data.profile.state,
      pincode: data.profile.pincode,
      country: data.profile.country,
      registeredLocation: data.profile.registeredLocation,
      logoFileName: data.profile.logoFileName,
      invoiceFormat: data.profile.invoiceFormat,
      version: data.profile.version,
    },
    compliance: data.compliance,
    assignment: {
      oldAccountingApproved: data.assignment.oldAccountingApproved,
      reportsPublished: data.assignment.reportsPublished,
      auditEnabled: data.assignment.auditEnabled,
      financialStatementsEnabled: data.assignment.financialStatementsEnabled,
      reportSigningEnabled: data.assignment.reportSigningEnabled,
      bankProjectReportsEnabled: data.assignment.bankProjectReportsEnabled,
      staffDelegationEnabled: data.assignment.staffDelegationEnabled,
      version: data.assignment.version,
    },
    workspace: data.workspace,
  };
}

function clientAccess(access: AuthoritativeClientData['access']) {
  return {
    loginEnabled: access.loginEnabled,
    mobileLoginEnabled: access.mobileLoginEnabled,
    webLoginEnabled: access.webLoginEnabled,
    twoFactorRequired: access.twoFactorRequired,
    accountLocked: access.accountLocked,
    subscriptionPlan: access.subscriptionPlan,
    billingMode: access.billingMode,
    accountingMode: access.accountingMode,
    purchaseEntryMode: access.purchaseEntryMode,
    salesEntryMode: access.salesEntryMode,
    modules: access.modules,
    dashboardWidgets: access.dashboardWidgets,
    documentHubAccess: access.documentHubAccess,
  };
}