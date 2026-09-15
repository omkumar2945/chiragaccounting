import { describe, expect, it } from 'vitest';

import { clientDataForRole } from '../src/services/clientDataVisibility.js';

const clientData = {
  client: {
    id: '42', name: 'Client ABC', email: 'client@example.com', mobile: '9876543210',
    firmName: 'ABC Traders', role: 'client', accountOrigin: 'imported', clientStatus: 'active',
    loginStatus: 'active', isActive: true, mustChangePassword: false,
    createdAt: '2026-01-01T00:00:00.000Z', lastLoginAt: null,
  },
  profile: {
    legalName: 'ABC Traders', gstin: '29ABCDE1234F1Z5', pan: 'ABCDE1234F', aadhaar: '123412341234',
    address: 'Main Road', city: 'Bengaluru', state: 'Karnataka', pincode: '560001', country: 'India',
    registeredLocation: { pincode: '560001' }, logoFileName: 'logo.jpg', logoDataBase64: 'base64-logo',
    invoiceFormat: 'Classic', documentMetadata: { privateNote: 'Internal' }, lastUpdatedAt: '2026-01-01T00:00:00.000Z', version: 3,
  },
  compliance: {
    gstRegistrationType: 'regular', accountingEnabled: true, gstEnabled: true,
    services: ['GST'], servicePeriods: [], version: 3,
  },
  assignment: {
    accountantUserId: '11', caUserId: '12', oldAccountingApproved: true, reportsPublished: true,
    auditEnabled: true, financialStatementsEnabled: true, reportSigningEnabled: true,
    bankProjectReportsEnabled: false, staffDelegationEnabled: true, version: 3,
  },
  access: {
    loginEnabled: true, mobileLoginEnabled: true, webLoginEnabled: true, twoFactorRequired: true,
    accountLocked: false, subscriptionPlan: 'premium', billingMode: 'fullBillingSoftware',
    accountingMode: 'accountsOnly', purchaseEntryMode: 'both', salesEntryMode: 'both',
    modules: { gst: true }, dashboardWidgets: { dashboard: true }, documentHubAccess: { upload: true }, version: 3,
  },
  workspace: {
    client360Enabled: true, documentFolderEnabled: true, complianceWorkspaceEnabled: true,
    accountingWorkspaceEnabled: true, aiWorkspaceEnabled: true, notificationSettingsEnabled: true, version: 3,
  },
};

describe('authoritative client data visibility', () => {
  it('retains the full aggregate only for administrators', () => {
    const result = clientDataForRole('admin', clientData);

    expect(result).toEqual(clientData);
  });

  it('exposes only the client\'s own effective portal policy', () => {
    const result = clientDataForRole('client', clientData);

    expect(result).not.toHaveProperty('assignment');
    expect(result.client).not.toHaveProperty('accountOrigin');
    expect(result.client).not.toHaveProperty('mustChangePassword');
    expect(result).toHaveProperty('access.modules', { gst: true });
    expect(result).not.toHaveProperty('access.version');
  });

  it('does not expose staff identifiers or sensitive profile metadata to assigned staff', () => {
    const result = clientDataForRole('accountant', clientData) as typeof clientData;

    expect(result).not.toHaveProperty('access');
    expect(result.assignment).not.toHaveProperty('accountantUserId');
    expect(result.assignment).not.toHaveProperty('caUserId');
    expect(result.profile).not.toHaveProperty('aadhaar');
    expect(result.profile).not.toHaveProperty('documentMetadata');
  });
});