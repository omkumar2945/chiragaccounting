/// ─────────────────────────────────────────────────────────────────
///  API CONFIGURATION
///  1. Set [useMockApi] = false when your backend is ready.
///  2. Set [baseUrl] to your real backend URL.
/// ─────────────────────────────────────────────────────────────────
class ApiConstants {
  ApiConstants._();

  /// Set at runtime with --dart-define=USE_MOCK_API=true|false.
  /// Defaults to false so production builds never fall back to local demo users.
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  /// Set at runtime with --dart-define=API_BASE_URL=https://your-host/v1.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.chiragca.com/v1',
  );

  // Connection & receive timeouts (milliseconds)
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;

  // ── Auth endpoints ─────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String firebasePhoneLogin = '/auth/firebase-phone';
  static const String loginOtpSend = '/auth/send-otp';
  static const String loginOtpVerify = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';
  static const String register = '/auth/register';

  // ── User endpoints ─────────────────────────────────────────────
  static const String me = '/users/me';
  static const String updateProfile = '/users/me';
  static const String adminClients = '/admin/clients';

  // ── GST module endpoints ───────────────────────────────────────
  static const String gstGstr1 = '/gst/gstr1';
  static const String gstGstr3b = '/gst/gstr3b';
  static const String gstGstr2bMatching = '/gst/gstr2b/matching';
  static const String gstReturnStatus = '/gst/returns/status';
  static const String gstAnalytics = '/gst/analytics';

  // ── OCR / AI extraction endpoints ─────────────────────────────
  static const String invoiceExtraction = '/invoice/extract';

  // ── Command center endpoints ───────────────────────────────────
  static const String command = '/command';
  static const String commandConfirm = '/command/confirm';
  static const String commandCancel = '/command/cancel';

  static String commandStatus(String commandId) => '/command/status/$commandId';

  // ── Header keys ────────────────────────────────────────────────
  static const String authHeader = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
}
