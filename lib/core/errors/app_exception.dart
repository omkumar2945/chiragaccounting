import 'dart:developer' as developer;

import 'error_code.dart';

/// Base exception class for the application
class AppException implements Exception {
  final ErrorCode errorCode;
  final String? customMessage;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final dynamic metadata;

  AppException({
    required this.errorCode,
    this.customMessage,
    this.originalError,
    this.stackTrace,
    this.metadata,
  });

  /// Get the display message
  String get message => customMessage ?? errorCode.message;

  /// Get the error code as integer
  int get code => errorCode.code;

  /// Get the category
  String get category => errorCode.category;

  /// Check if error is from network
  bool get isNetworkError => errorCode == ErrorCode.networkError;

  /// Check if error is validation error
  bool get isValidationError => errorCode == ErrorCode.validationError;

  /// Check if error is authentication error
  bool get isAuthError =>
      errorCode == ErrorCode.unauthorizedError ||
      errorCode == ErrorCode.sessionExpired ||
      errorCode == ErrorCode.invalidToken;

  /// Check if error is not found
  bool get isNotFound => errorCode == ErrorCode.notFoundError;

  /// Check if error is server error
  bool get isServerError => errorCode == ErrorCode.serverError;

  @override
  String toString() {
    return 'AppException{'
        'code: $code, '
        'message: $message, '
        'category: $category'
        '${originalError != null ? ', originalError: $originalError' : ''}'
        '}';
  }

  /// Create a copy with new message
  AppException copyWith({String? message}) {
    return AppException(
      errorCode: errorCode,
      customMessage: message ?? customMessage,
      originalError: originalError,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Log the error
  void log() {
    developer.log(
      '[ERROR] [$category:$code] $message'
      '${originalError != null ? '\n  Original: $originalError' : ''}'
      '${metadata != null ? '\n  Metadata: $metadata' : ''}',
      name: 'AppException',
      error: originalError,
      stackTrace: stackTrace,
    );
  }
}

/// Validation exception
class ValidationException extends AppException {
  ValidationException({
    required String message,
    super.metadata,
  }) : super(
    errorCode: ErrorCode.validationError,
    customMessage: message,
  );
}

/// Customer exception
class CustomerException extends AppException {
  CustomerException({
    required super.errorCode,
    String? message,
    super.originalError,
    super.stackTrace,
    super.metadata,
  }) : super(
    customMessage: message,
  );
}

/// Sales invoice exception
class InvoiceException extends AppException {
  InvoiceException({
    required super.errorCode,
    String? message,
    super.originalError,
    super.stackTrace,
    super.metadata,
  }) : super(
    customMessage: message,
  );
}

/// Product exception
class ProductException extends AppException {
  ProductException({
    required super.errorCode,
    String? message,
    super.originalError,
    super.stackTrace,
    super.metadata,
  }) : super(
    customMessage: message,
  );
}

/// Authentication exception
class AuthException extends AppException {
  AuthException({
    required super.errorCode,
    String? message,
    super.originalError,
    super.stackTrace,
    super.metadata,
  }) : super(
    customMessage: message,
  );
}

/// Database exception
class DatabaseException extends AppException {
  DatabaseException({
    required super.errorCode,
    String? message,
    super.originalError,
    super.stackTrace,
    super.metadata,
  }) : super(
    customMessage: message,
  );
}

/// Network exception
class NetworkException extends AppException {
  NetworkException({
    String? message,
    super.originalError,
    super.stackTrace,
  }) : super(
    errorCode: ErrorCode.networkError,
    customMessage: message,
  );
}

/// Server exception
class ServerException extends AppException {
  ServerException({
    String? message,
    super.originalError,
    super.stackTrace,
    int? statusCode,
  }) : super(
    errorCode: ErrorCode.serverError,
    customMessage: message,
    metadata: {'statusCode': statusCode},
  );
}

/// Timeout exception
class TimeoutException extends AppException {
  TimeoutException({
    String? message,
  }) : super(
    errorCode: ErrorCode.timeoutError,
    customMessage: message,
  );
}
