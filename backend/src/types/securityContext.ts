export type UserRole = 'super_admin' | 'admin' | 'manager' | 'accountant' | 'auditor' | 'client';

export interface SecurityContext {
  userId: string;
  role: UserRole;
  tenantId: string;
  companyId: string;
  branchId: string;
  financialYear: string;
  permissions: string[];
}
