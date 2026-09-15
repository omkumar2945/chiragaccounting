import 'package:dio/dio.dart';
import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/secure_storage_service.dart';
import 'dart:io';

/// Dio client with automatic JWT injection and token-refresh on 401.
class ApiClient {
  ApiClient._();

  static final Dio _dio = _build();
  static Dio get dio => _dio;

  static Dio _build() {
    final d = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: ApiConstants.connectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
        headers: {
          ApiConstants.contentType: ApiConstants.applicationJson,
        },
        responseType: ResponseType.json,
      ),
    );
    d.interceptors.add(_AuthInterceptor(d));
    return d;
  }
}

/// Interceptor: attaches Bearer token on every request and silently
/// refreshes the access token when a 401 is received.
class _AuthInterceptor extends QueuedInterceptorsWrapper {
  final Dio _dio;

  _AuthInterceptor(this._dio);

  bool _isPublicPasswordResetRequest(String path) {
    return path == ApiConstants.forgotPassword ||
        path == ApiConstants.loginOtpVerify ||
        path == ApiConstants.resetPassword;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicPasswordResetRequest(options.path)) {
      final token = await SecureStorageService.getAccessToken();
      if (token != null) {
        options.headers[ApiConstants.authHeader] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt refresh for 401 responses (not for the refresh call itself)
    if (err.response?.statusCode == 401 &&
      !_isPublicPasswordResetRequest(err.requestOptions.path) &&
        err.requestOptions.path != ApiConstants.refreshToken) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Retry the original request with the new access token
        final newToken = await SecureStorageService.getAccessToken();
        final opts = err.requestOptions;
        opts.headers[ApiConstants.authHeader] = 'Bearer $newToken';
        try {
          final retryResponse = await _dio.fetch(opts);
          handler.resolve(retryResponse);
          return;
        } catch (e) {
          // Retry also failed — fall through to error handler
        }
      }
    }
    handler.next(err);
  }

  /// Calls the refresh-token endpoint. Returns true if successful.
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {
          ApiConstants.contentType: ApiConstants.applicationJson,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await SecureStorageService.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String? ?? refreshToken,
          expiresAt: DateTime.parse(data['expiresAt'] as String),
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// Converts a [DioException] into a user-readable [ApiError].
class ApiError implements Exception {
  final String message;
  final int? statusCode;

  const ApiError(this.message, {this.statusCode});

  factory ApiError.fromDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiError(
          'Connection timed out. Please check your internet and try again.');
    }
    if (e.type == DioExceptionType.connectionError) {
      final rawError = e.error;
      if (rawError is SocketException) {
        final rawMessage = rawError.message.toLowerCase();
        final dnsFailure = rawMessage.contains('failed host lookup') ||
            rawMessage.contains('no address associated with hostname') ||
            rawMessage.contains('name or service not known');
        if (dnsFailure) {
          return const ApiError(
              'Server address could not be resolved. Please verify API base URL or DNS settings.');
        }
      }
      return const ApiError(
          'Unable to connect to server. Please check your internet connection.');
    }
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Something went wrong. Please try again.';

    if (data is Map<String, dynamic>) {
      message = (data['message'] as String?) ??
          (data['error'] as String?) ??
          message;
    }

    switch (statusCode) {
      case 400:
        return ApiError(message, statusCode: statusCode);
      case 401:
        return ApiError(message.isNotEmpty ? message : 'Session expired. Please login again.',
            statusCode: statusCode);
      case 403:
        return ApiError('You do not have permission to perform this action.',
            statusCode: statusCode);
      case 404:
        return ApiError('Resource not found.', statusCode: statusCode);
      case 422:
        return ApiError(message, statusCode: statusCode);
      case 429:
        return ApiError('Too many requests. Please wait and try again.',
            statusCode: statusCode);
      case 500:
      case 502:
      case 503:
        return ApiError('Server error. Please try again later.',
            statusCode: statusCode);
      default:
        return ApiError(message, statusCode: statusCode);
    }
  }

  @override
  String toString() => message;
}
