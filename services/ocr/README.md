# Chirag OCR Service

This repository owns the complete OCR service source, persistent document storage, OCR processing, draft validation, audit history, and dashboard statistics. It has no runtime or build dependency on the former external source folder.

The accountant-facing user interface is the native Flutter AI Workbench. The service is an optional repository-local persistence and background-processing API; the Flutter upload and auto-detection flow does not require its `wwwroot` panel.

## Run locally

```powershell
dotnet run --project services\ocr\src\Chirag.Ocr.Api\Chirag.Ocr.Api.csproj
flutter run -d chrome --dart-define=USE_MOCK_API=true --dart-define=OCR_API_BASE_URL=http://localhost:5071
```

Development requests use `X-Client-Id`, `X-Accountant-Id`, and `X-Role`. Production uses the Chirag JWT and requires `client_id`, `accountant_id`, and role claims.

## Workflow

1. A client uploads through Chat or Uploads.
2. Flutter resolves the assigned accountant and submits the file to `/ocr/upload`.
3. The same document appears in the assigned accountant's Workbench queue.
4. Only assigned accounting staff can edit/validate/confirm the accounting draft.
5. The client can rename or delete the source document until the entry is posted.
6. Saved/posted/completed documents are locked; dashboards and reports use completed accounting records.

Set production CORS origins in `Cors:AllowedOrigins`. SQLite is the local default; configure `ConnectionStrings:Ocr` for the deployment database path.