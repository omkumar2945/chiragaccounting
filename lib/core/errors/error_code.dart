/// Error codes for the application
enum ErrorCode {
  // General Errors (1000-1999)
  unknown,
  validationError,
  networkError,
  serverError,
  timeoutError,
  unauthorizedError,
  forbiddenError,
  notFoundError,

  // Customer Errors (2000-2999)
  customerNotFound,
  customerAlreadyExists,
  invalidCustomerCode,
  invalidCustomerEmail,
  duplicateCustomerCode,
  duplicateCustomerEmail,
  customerDeleteFailed,
  customerUpdateFailed,
  customerAddFailed,

  // Sales Errors (3000-3999)
  invoiceNotFound,
  invoiceAlreadyExists,
  invalidInvoiceNumber,
  invoiceDeleteFailed,
  invoiceUpdateFailed,
  invoiceAddFailed,
  productRequired,
  invalidProductData,

  // Product Errors (4000-4999)
  productNotFound,
  productAlreadyExists,
  invalidProductCode,
  invalidProductPrice,
  productDeleteFailed,
  productUpdateFailed,
  productAddFailed,

  // Purchase Errors (5000-5999)
  purchaseOrderNotFound,
  purchaseOrderAlreadyExists,
  invalidPONumber,
  poDeleteFailed,
  poUpdateFailed,
  poAddFailed,

  // Auth Errors (6000-6999)
  invalidCredentials,
  userNotFound,
  sessionExpired,
  invalidToken,
  loginFailed,
  logoutFailed,

  // Database Errors (7000-7999)
  databaseError,
  queryError,
  transactionError,
  dataIntegrityError,

  // File Errors (8000-8999)
  fileNotFound,
  fileReadError,
  fileWriteError,
  invalidFileFormat,
  fileTooLarge,

  // PDF/Report Errors (9000-9999)
  pdfGenerationError,
  reportGenerationError,
  invalidReportData,
}

extension ErrorCodeExtension on ErrorCode {
  /// Get HTTP status code
  int get statusCode {
    switch (this) {
      case ErrorCode.validationError:
        return 400;
      case ErrorCode.unauthorizedError:
        return 401;
      case ErrorCode.forbiddenError:
        return 403;
      case ErrorCode.notFoundError:
        return 404;
      case ErrorCode.timeoutError:
        return 408;
      case ErrorCode.serverError:
        return 500;
      case ErrorCode.networkError:
        return 0; // Not HTTP
      default:
        return 400;
    }
  }

  /// Get user-friendly message
  String get message {
    switch (this) {
      // General
      case ErrorCode.unknown:
        return 'An unknown error occurred';
      case ErrorCode.validationError:
        return 'Please check your input and try again';
      case ErrorCode.networkError:
        return 'Network error. Please check your connection';
      case ErrorCode.serverError:
        return 'Server error. Please try again later';
      case ErrorCode.timeoutError:
        return 'Request timed out. Please try again';
      case ErrorCode.unauthorizedError:
        return 'Unauthorized access';
      case ErrorCode.forbiddenError:
        return 'You do not have permission';
      case ErrorCode.notFoundError:
        return 'Resource not found';

      // Customer
      case ErrorCode.customerNotFound:
        return 'Customer not found';
      case ErrorCode.customerAlreadyExists:
        return 'Customer already exists';
      case ErrorCode.invalidCustomerCode:
        return 'Invalid customer code';
      case ErrorCode.invalidCustomerEmail:
        return 'Invalid email address';
      case ErrorCode.duplicateCustomerCode:
        return 'Customer code already exists';
      case ErrorCode.duplicateCustomerEmail:
        return 'Email already registered';
      case ErrorCode.customerDeleteFailed:
        return 'Failed to delete customer';
      case ErrorCode.customerUpdateFailed:
        return 'Failed to update customer';
      case ErrorCode.customerAddFailed:
        return 'Failed to add customer';

      // Sales
      case ErrorCode.invoiceNotFound:
        return 'Invoice not found';
      case ErrorCode.invoiceAlreadyExists:
        return 'Invoice already exists';
      case ErrorCode.invalidInvoiceNumber:
        return 'Invalid invoice number';
      case ErrorCode.invoiceDeleteFailed:
        return 'Failed to delete invoice';
      case ErrorCode.invoiceUpdateFailed:
        return 'Failed to update invoice';
      case ErrorCode.invoiceAddFailed:
        return 'Failed to save invoice';
      case ErrorCode.productRequired:
        return 'At least one product is required';
      case ErrorCode.invalidProductData:
        return 'Invalid product data';

      // Product
      case ErrorCode.productNotFound:
        return 'Product not found';
      case ErrorCode.productAlreadyExists:
        return 'Product already exists';
      case ErrorCode.invalidProductCode:
        return 'Invalid product code';
      case ErrorCode.invalidProductPrice:
        return 'Invalid product price';
      case ErrorCode.productDeleteFailed:
        return 'Failed to delete product';
      case ErrorCode.productUpdateFailed:
        return 'Failed to update product';
      case ErrorCode.productAddFailed:
        return 'Failed to add product';

      // Purchase
      case ErrorCode.purchaseOrderNotFound:
        return 'Purchase order not found';
      case ErrorCode.purchaseOrderAlreadyExists:
        return 'Purchase order already exists';
      case ErrorCode.invalidPONumber:
        return 'Invalid PO number';
      case ErrorCode.poDeleteFailed:
        return 'Failed to delete PO';
      case ErrorCode.poUpdateFailed:
        return 'Failed to update PO';
      case ErrorCode.poAddFailed:
        return 'Failed to create PO';

      // Auth
      case ErrorCode.invalidCredentials:
        return 'Invalid username or password';
      case ErrorCode.userNotFound:
        return 'User not found';
      case ErrorCode.sessionExpired:
        return 'Session expired. Please login again';
      case ErrorCode.invalidToken:
        return 'Invalid authentication token';
      case ErrorCode.loginFailed:
        return 'Login failed';
      case ErrorCode.logoutFailed:
        return 'Logout failed';

      // Database
      case ErrorCode.databaseError:
        return 'Database error occurred';
      case ErrorCode.queryError:
        return 'Query error occurred';
      case ErrorCode.transactionError:
        return 'Transaction failed';
      case ErrorCode.dataIntegrityError:
        return 'Data integrity error';

      // File
      case ErrorCode.fileNotFound:
        return 'File not found';
      case ErrorCode.fileReadError:
        return 'Failed to read file';
      case ErrorCode.fileWriteError:
        return 'Failed to write file';
      case ErrorCode.invalidFileFormat:
        return 'Invalid file format';
      case ErrorCode.fileTooLarge:
        return 'File is too large';

      // PDF/Report
      case ErrorCode.pdfGenerationError:
        return 'Failed to generate PDF';
      case ErrorCode.reportGenerationError:
        return 'Failed to generate report';
      case ErrorCode.invalidReportData:
        return 'Invalid report data';
    }
  }

  /// Get error code number for logging
  int get code {
    return index;
  }

  /// Get error category
  String get category {
    if (index >= 1000 && index < 2000) {
      return 'GENERAL';
    } else if (index >= 2000 && index < 3000) {
      return 'CUSTOMER';
    } else if (index >= 3000 && index < 4000) {
      return 'SALES';
    } else if (index >= 4000 && index < 5000) {
      return 'PRODUCT';
    } else if (index >= 5000 && index < 6000) {
      return 'PURCHASE';
    } else if (index >= 6000 && index < 7000) {
      return 'AUTH';
    } else if (index >= 7000 && index < 8000) {
      return 'DATABASE';
    } else if (index >= 8000 && index < 9000) {
      return 'FILE';
    } else if (index >= 9000 && index < 10000) {
      return 'PDF_REPORT';
    }
    return 'UNKNOWN';
  }
}
