# Authoritative Data Migration Plan

## Identity Rule

Do not create duplicate Admin records for migration, testing, or deployment.
The MySQL `users` table is the canonical user identity store and enforces unique
email and mobile values. The existing bootstrap-admin process is idempotent: it
does not create or alter an Admin when the configured email or mobile already
exists.

This does not prohibit legitimately authorized roles in the future. It means a
single existing Admin identity must be reused for the acceptance tests below;
do not create `Admin A` and `Admin B` test identities to simulate devices.

## Cross-Device Acceptance Test

Use four existing, distinct role identities on separate devices or browser
profiles:

```text
Device 1: existing Admin
Device 2: existing CA/Auditor
Device 3: existing Accountant
Device 4: existing Client
```

The test verifies server-authoritative data, not separate Admin accounts:

1. The existing Admin assigns Client ABC to the existing Accountant and CA/Auditor.
2. The Accountant refreshes and receives Client ABC from the authenticated API.
3. The CA/Auditor refreshes and receives the same authorized assignment.
4. Client ABC refreshes and receives only its authorized client state.
5. The existing Admin updates profile, compliance, access policy, and workspace.
6. The Accountant, CA/Auditor, and Client refresh independently and see only the
   updated fields each role is authorized to read.

Repeat the same pattern for tasks, timeline events, GST status, accounting
records, financial records, reports, notifications, documents, and Tally state
after their MySQL-backed APIs are introduced. No SharedPreferences record may
be used as the expected source in these tests.

## First-Slice API Acceptance

Run this only against a non-production MySQL database after the additive schema
has been applied there. Use authenticated sessions for the four existing
identities above; do not create an additional Admin account.

1. The existing Admin calls `GET /v1/clients` and sees the client list. The
   Admin calls `PATCH /v1/clients/{clientId}/assignments` with the existing
   Accountant and CA/Auditor IDs.
2. The Accountant and CA/Auditor each call `GET /v1/clients` from separate
   browser profiles or devices. Each receives Client ABC only while assigned.
3. The Client calls `GET /v1/clients` and `GET
   /v1/clients/{clientId}/authoritative`. The response contains its own client,
   profile, compliance, and workspace state, but no access-policy internals,
   assignment IDs, account-origin details, or password-change flag.
4. The Admin changes only one profile field with `PATCH
   /v1/clients/{clientId}/profile`. Confirm that unrelated populated profile
   values remain unchanged. Empty strings are rejected; a deliberate removal
   uses the `clearFields` array.
5. The Admin changes compliance, access policy, and workspace settings. Confirm
   that the same update is visible after independent refreshes on the assigned
   Accountant, CA/Auditor, and Client devices according to the response policy.
6. Confirm `client_data_change_log` contains one actor-attributed event for
   each successful change. Confirm imports write `applied` or `conflict` rows
   to `data_migration_reconciliation`; an existing Admin identity must produce
   a conflict, never an imported Client record.

## Current First Slice

The unexecuted additive MySQL schema adds `client_profiles`,
`client_compliance`, `client_assignments`, `client_access_policies`,
`client_workspaces`, and `data_migration_reconciliation`. Their APIs are
authenticated through the canonical MySQL `users` record. No migration runs
automatically during application deployment.

## Safe Cutover Rule

Before any production migration: take an RDS snapshot, export SQL Server data,
export local business records, record checksums in the reconciliation table,
validate conflicts, and obtain explicit approval. Retain all source records
until reconciliation is complete. Do not deploy or run `npm run db:migrate`
against production as part of this work.