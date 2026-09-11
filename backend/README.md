# CHIRAG Command Center Backend

Production-oriented backend for conversational command execution.

## What this backend includes

- Authenticated command APIs
- Conversation state engine with pending questions and confirmation gates
- Intent/entity/context processing (deterministic)
- Tenant-scoped persistence in MSSQL
- Audit logging and idempotency
- Draft-first financial posting pipeline
- Provider integrations for accounting, print, e-invoice, e-way bill with `CONFIGURATION_REQUIRED` handling

## APIs

- `POST /api/command`
- `POST /api/command/confirm`
- `POST /api/command/cancel`
- `GET /api/command/status/:commandId`
- `GET /api/gstzen/status`
- `GET /api/gstzen/version`
- `POST /api/gstzen/einvoice/generate`
- `POST /api/gstzen/einvoice/cancel`
- `POST /api/gstzen/eway-bill/generate`
- `POST /api/gstzen/eway-bill/cancel`
- `GET /health`

## Firebase phone OTP

The Flutter app signs in with Firebase Phone Authentication, then sends its
short-lived Firebase ID token to `POST /v1/auth/firebase-phone`. The backend
verifies that token, finds the existing user by verified mobile number, and
issues the normal Chirag session. Firebase verification never registers a user
or grants a role.

Before deploying, enable the **Phone** provider and add the production domain
under Firebase Authentication's authorized domains. Supply a Firebase service
account JSON document through the deployment secret named
`FIREBASE_SERVICE_ACCOUNT_JSON`. Do not put this value in Flutter build
variables, source control, or client-side configuration.

The Flutter production build also needs the public Firebase web/app values:

```text
FIREBASE_API_KEY
FIREBASE_APP_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_PROJECT_ID
FIREBASE_AUTH_DOMAIN
```

Pass them as `--dart-define` values during `flutter build web`. Configure the
Firebase web app's authorized domain before testing OTP in Chrome.

## Email OTP

Registered users can request a six-digit verification code at
`POST /api/auth/send-otp` with `email` (or `identifier`), `userType`, and an
optional `purpose` of `login` or `password_reset`. Verify a login code at
`POST /api/auth/verify-otp`; a successful verification creates the normal app
session and records the email as verified. Password recovery uses
`POST /api/auth/forgot-password` and `POST /api/auth/reset-password`.

Set these deployment secrets before enabling the flow:

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=service-account@example.com
SMTP_PASSWORD=provider-app-password
SMTP_FROM=no-reply@example.com
```

Codes are hashed before SQL storage, expire after 10 minutes, allow five
attempts, and are consumed after successful verification. The backend returns
`503` rather than confirming a code when SMTP has not been configured.

All `/api/gstzen/*` routes require the application's bearer JWT. The GSTZen
authentication token is added by the backend and is never accepted from or
returned to the Flutter client.

## GSTZen activation

Set these values in the backend environment:

```env
GSTZEN_ACCOUNT_EMAIL=the-email-activated-in-gstzen
GSTZEN_TOKEN=the-token-from-the-gstzen-integration-page
GSTZEN_BASE_URL=https://my.gstzen.in/~gstzen/a/post-einvoice-data/einvoice-json
GSTZEN_EWAY_BILL_BASE_URL=https://my.gstzen.in/~gstzen/a/ewbapi
```

`GSTZEN_ACCOUNT_EMAIL` identifies the activated GSTZen subscription. GSTZen API
authentication uses `GSTZEN_TOKEN`, not the email address. Store the token in
the deployment secret manager and never in Flutter source or build variables.

The authenticated `/api/gstzen` routes cover GSTZen's published E-Invoice and
E-Way Bill API contract: generate/cancel/get e-invoice, generate/cancel E-Way
Bill on IRN, standalone create/cancel/get/update/extend/close E-Way Bill,
consolidated E-Way Bills, multi-vehicle movement, and transporter views.
Cancel E-Way Bill on IRN uses `POST` with `application/json` at
`GSTZEN_BASE_URL/cancelewb/` and authenticates with the server-side `Token`
header.
Get E-Invoice by IRN uses `POST` with `application/json` at
`GSTZEN_BASE_URL/geteinv/`, authenticates with the server-side `Token` header,
and requires `SellerDtls.Gstin` plus a 64-character hexadecimal `Irn`. Include
the optional `irp` field (for example, `"NIC1"`) to route the lookup to a
specific invoice registration portal.
Standalone E-Way Bill mutations require the client GSTIN in the `X-GSTIN`
request header. The backend forwards it to GSTZen as the required `gstin`
header; the GSTZen token never leaves the backend.

Standalone request bodies are validated separately for generate, cancel,
Part B, transporter assignment, lookup, consolidated bills, extension,
multi-vehicle movement, and closure. The Part B fields are sent as
`TransDocDate` and `TransDocNo`; trailing spaces shown in older documentation
examples are treated as formatting errors and are not part of the JSON keys.
GSTZen's public transporter-view pages require authentication and do not expose
their query contract. The application retains explicit GSTIN/date/state inputs
for these views until GSTZen publishes or supplies the activated-account
contract.

Flutter callers use `GstIntegrationAdapter.execute`. Include `gstin` in the
payload for standalone E-Way Bill actions. The adapter removes that routing
field from the JSON body and sends it as `X-GSTIN`.

Supported action names:

```text
generate-einvoice
cancel-einvoice
get-einvoice
generate-eway-bill
cancel-eway-bill
create-eway-bill
cancel-standalone-eway-bill
update-eway-bill-part-b
update-eway-bill-transporter
get-eway-bill
generate-consolidated-eway-bill
get-consolidated-eway-bill
extend-eway-bill
initiate-eway-bill-multi-vehicle
add-eway-bill-multi-vehicle
change-eway-bill-multi-vehicle
close-eway-bill
get-eway-bill-transporter-view
get-eway-bill-transporter-state-view
get-eway-bill-transporter-gstin-view
```

GSTZen's public documentation does not publish callable contracts for GSTR-1,
GSTR-3B, GSTR-2B, filing status, validators, analytics, or GSTN sessions. These
must not be pointed at the E-Invoice URL. Obtain the subscription-specific base
URLs, authentication requirements, and schemas from GSTZen before activating
those modules.

## Run

1. Copy `.env.example` to `.env` and fill values.
2. Create DB objects from `src/db/schema.sql`.
3. Install deps: `npm install`
4. Start dev server: `npm run dev`

## Production

1. Build: `npm run build`
2. Start: `npm start`

The production entrypoint is `dist/src/index.js`.

## AWS Deployment

This backend is suitable for AWS App Runner, ECS, or Elastic Beanstalk as a containerized Node service.

1. Build the image from `backend/`:
	`docker build -t chirag-command-center-backend .`
2. Push the image to Amazon ECR.
3. Create an App Runner or ECS service using container port `8080`.
4. Configure the environment variables from `.env.example` in AWS Secrets Manager or the service environment settings.
5. Point the health check to `GET /health`.

### ECS Fargate

Use the sample task definition at `deploy/ecs-task-definition.json` as the base for ECS.

1. Build and push the image to ECR.
2. Replace `<account-id>` and `<region>` placeholders in `deploy/ecs-task-definition.json`.
3. Create the referenced Secrets Manager entries or change the ARNs to match your secret names.
4. Register the task definition and create an ECS service behind an ALB.
5. Set the ALB target group health check path to `GET /health`.

For Fargate, ensure the ECS service security group can reach the MSSQL host and that the ALB security group can reach the service on port `8080`.

### Deploy from VS Code

One-time setup:

1. Copy `backend/deploy/deployment-settings.example.json` to `backend/deploy/deployment-settings.json` and replace its placeholder values with your ECS cluster, service, and IAM role ARNs. The local settings file is ignored by Git.
2. Install and authenticate the AWS CLI for the target account, for example: `aws configure` or `aws sso login`.
3. Start Docker Desktop and ensure it is running.

After making backend changes, press `Ctrl+Shift+B` in VS Code to deploy. You can also open the Command Palette with `Ctrl+Shift+P`, run **Tasks: Run Task**, then choose **AWS: Deploy Backend to ECS**. The task builds the image, pushes it to ECR, deploys the new task revision, and waits for the ECS service to stabilize.

Minimum required variables for startup:

- `JWT_SECRET`
- `MSSQL_SERVER`
- `MSSQL_DATABASE`
- `MSSQL_USER`
- `MSSQL_PASSWORD`

`PORT` is already supported and should usually be left to the AWS runtime.

## Security

- Requires bearer JWT.
- Context is derived from token claims, not from request body.
- All data access is tenant scoped by `tenantId/companyId/branchId/financialYear/userId`.
