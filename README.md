# Chirag Accounting

Flutter client for Android, iOS, and web.

## Production Builds

Create the local release configuration first:

```powershell
Copy-Item .env.release.example .env.release
```

Fill in the production API URL and Firebase public app values in `.env.release`.
The URL must point to a live API gateway; the currently checked public host does
not yet expose the backend `/api` or `/v1` routes.

Build each release target from the repository root:

```powershell
.\tool -Target web -BuildName 1.0.0 -BuildNumber 1
.\tool -Target android-aab -BuildName 1.0.0 -BuildNumber 1
.\tool -Target android-apk -BuildName 1.0.0 -BuildNumber 1
```

Build iOS from a macOS machine with Xcode:

```powershell
.\tool -Target ios -BuildName 1.0.0 -BuildNumber 1
```

Generated artifacts:

- Web: `build/web/`
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Android App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- iOS IPA: `build/ios/ipa/`

Android Play Store distribution also requires a private release keystore and
`android/key.properties`; both are intentionally excluded from Git. iOS App
Store distribution requires a configured Apple Developer signing team in Xcode.

Create the Android upload key once, then copy and complete the template:

```powershell
keytool -genkeypair -v -keystore android/upload-keystore.jks -alias chirag-accounting -keyalg RSA -keysize 2048 -validity 10000
Copy-Item android/key.properties.example android/key.properties
```

## Deploy Web App to AWS

The web app can be deployed as Flutter static files to S3/CloudFront or directly to the production EC2 web root with CodePipeline, CodeBuild, and CodeDeploy.

One-time setup:

1. Copy `scripts/web-deployment-settings.example.json` to `scripts/web-deployment-settings.json` and replace the bucket, CloudFront distribution, and public URL placeholders. The settings file is excluded from Git.
2. Copy `.env.release.example` to `.env.release` and fill in the production API and Firebase values.
3. Create an S3 bucket configured for CloudFront static hosting, and grant the authenticated AWS CLI identity permission to upload and delete its objects plus create CloudFront invalidations.
4. Authenticate the AWS CLI with `aws configure` or `aws sso login`, and make sure Flutter is installed.

In VS Code, open the Command Palette with `Ctrl+Shift+P`, run **Tasks: Run Task**, and choose **AWS: Deploy Web App to S3 and CloudFront**. The task builds the release web app, syncs `build/web/` to S3, disables caching for `index.html`, and invalidates CloudFront so visitors receive the new release.

### Automated EC2 Deployment

The repository includes `buildspec.yml` and `appspec.yml` for the CodePipeline already created in AWS. Configure its stages as **GitHub -> CodeBuild -> CodeDeploy**.

In the CodeBuild project's environment variables, add the production values from `.env.release`: `API_BASE_URL`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MEASUREMENT_ID`, and `FIREBASE_WEB_VAPID_KEY`. Do not commit a production `.env.release` file. Use Parameter Store or Secrets Manager for managed configuration values.

CodeDeploy installs the generated web files in `/var/www/chirag`, reloads Nginx, and verifies the local HTTP response. Before the first deployment, configure the live Nginx virtual host to serve this directory and verify it with `sudo nginx -T | grep root`. The EC2 instance must have a running CodeDeploy agent and an IAM instance role that allows CodeDeploy artifact access.
