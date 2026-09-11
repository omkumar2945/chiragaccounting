import 'package:chirag_accounting/features/roles/models/role_model.dart';

enum AccountOrigin {
  selfRegistered,
  adminOnboarded,
  imported,
  legacyUnknown;

  String get displayName => switch (this) {
    AccountOrigin.selfRegistered => 'Self Registered',
    AccountOrigin.adminOnboarded => 'Admin Onboarded',
    AccountOrigin.imported => 'Uploaded Client',
    AccountOrigin.legacyUnknown => 'Legacy Client',
  };

  bool get isAdminManaged =>
      this == AccountOrigin.adminOnboarded || this == AccountOrigin.imported;
}

enum ClientAccountStatus {
  draft,
  pendingApproval,
  notOnboarded,
  onboarded,
  active,
  inactive,
  suspended,
  archived;

  String get displayName => switch (this) {
    ClientAccountStatus.draft => 'Draft',
    ClientAccountStatus.pendingApproval => 'Pending Approval',
    ClientAccountStatus.notOnboarded => 'Not Onboarded',
    ClientAccountStatus.onboarded => 'Onboarded',
    ClientAccountStatus.active => 'Active',
    ClientAccountStatus.inactive => 'Inactive',
    ClientAccountStatus.suspended => 'Suspended',
    ClientAccountStatus.archived => 'Archived',
  };
}

enum ClientLoginStatus {
  loginNotCreated,
  credentialsSent,
  neverLoggedIn,
  active,
  passwordChanged,
  locked;

  String get displayName => switch (this) {
    ClientLoginStatus.loginNotCreated => 'Login Not Created',
    ClientLoginStatus.credentialsSent => 'Credentials Sent',
    ClientLoginStatus.neverLoggedIn => 'Never Logged In',
    ClientLoginStatus.active => 'Active',
    ClientLoginStatus.passwordChanged => 'Password Changed',
    ClientLoginStatus.locked => 'Locked',
  };
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final UserRole role;
  final String firmId;
  final String firmName;
  final String? profileImageUrl;
  final bool isActive;
  final bool isTwoFactorEnabled;
  final AccountOrigin accountOrigin;
  final ClientAccountStatus clientStatus;
  final ClientLoginStatus loginStatus;
  final bool mustChangePassword;
  final bool termsAccepted;
  final DateTime? onboardedAt;
  final DateTime? credentialsSentAt;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    required this.firmId,
    required this.firmName,
    this.profileImageUrl,
    required this.isActive,
    this.isTwoFactorEnabled = false,
    this.accountOrigin = AccountOrigin.legacyUnknown,
    this.clientStatus = ClientAccountStatus.active,
    this.loginStatus = ClientLoginStatus.active,
    this.mustChangePassword = false,
    this.termsAccepted = false,
    this.onboardedAt,
    this.credentialsSentAt,
    this.lastLoginAt,
    required this.createdAt,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? mobile,
    UserRole? role,
    String? firmId,
    String? firmName,
    String? profileImageUrl,
    bool? isActive,
    bool? isTwoFactorEnabled,
    AccountOrigin? accountOrigin,
    ClientAccountStatus? clientStatus,
    ClientLoginStatus? loginStatus,
    bool? mustChangePassword,
    bool? termsAccepted,
    DateTime? onboardedAt,
    bool clearOnboardedAt = false,
    DateTime? credentialsSentAt,
    bool clearCredentialsSentAt = false,
    DateTime? lastLoginAt,
    bool clearLastLoginAt = false,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      firmId: firmId ?? this.firmId,
      firmName: firmName ?? this.firmName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      isTwoFactorEnabled: isTwoFactorEnabled ?? this.isTwoFactorEnabled,
      accountOrigin: accountOrigin ?? this.accountOrigin,
      clientStatus: clientStatus ?? this.clientStatus,
      loginStatus: loginStatus ?? this.loginStatus,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      onboardedAt: clearOnboardedAt ? null : onboardedAt ?? this.onboardedAt,
      credentialsSentAt: clearCredentialsSentAt
          ? null
          : credentialsSentAt ?? this.credentialsSentAt,
      lastLoginAt: clearLastLoginAt ? null : lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole parseRole(String rawRole) {
      final key = rawRole.trim().toLowerCase().replaceAll(
        RegExp(r'[\s_-]+'),
        '',
      );
      switch (key) {
        case 'superadmin':
          return UserRole.superAdmin;
        case 'admin':
          return UserRole.admin;
        case 'partner':
          return UserRole.partner;
        case 'manager':
          return UserRole.manager;
        case 'firmadmin':
          return UserRole.firmAdmin;
        case 'businessowner':
        case 'business':
          return UserRole.businessOwner;
        case 'accountant':
          return UserRole.accountant;
        case 'dataentryoperator':
        case 'operator':
        case 'staff':
          return UserRole.dataEntryOperator;
        case 'checker':
        case 'ca':
        case 'caauditor':
        case 'auditor':
          return UserRole.checker;
        case 'client':
          return UserRole.client;
        default:
          throw FormatException('Unsupported user role: $rawRole');
      }
    }

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return fallback;
    }

    String readRole() {
      const roleKeys = [
        'role',
        'userRole',
        'user_role',
        'roleName',
        'role_name',
      ];
      for (final key in roleKeys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value is Map) {
          for (final nestedKey in ['name', 'code', 'slug', 'key', 'role']) {
            final nestedValue = value[nestedKey];
            if (nestedValue is String && nestedValue.trim().isNotEmpty) {
              return nestedValue.trim();
            }
          }
        }
      }
      throw const FormatException('Missing user role');
    }

    final roleRaw = readRole();
    final createdAtRaw = readString(['createdAt', 'created_at']);

    T enumValue<T extends Enum>(List<T> values, List<String> keys, T fallback) {
      final raw = readString(keys);
      return values.firstWhere(
        (value) => value.name == raw,
        orElse: () => fallback,
      );
    }

    DateTime? readDate(List<String> keys) {
      final raw = readString(keys);
      return raw.isEmpty ? null : DateTime.tryParse(raw);
    }

    return UserModel(
      id: readString(['id', '_id', 'userId'], fallback: 'unknown'),
      name: readString(['name', 'fullName'], fallback: 'User'),
      email: readString(['email']),
      mobile: readString(['mobile', 'phone', 'phoneNumber']),
      role: parseRole(roleRaw),
      firmId: readString(['firmId', 'firm_id', 'companyId']),
      firmName: readString([
        'firmName',
        'companyName',
      ], fallback: 'Default Firm'),
      profileImageUrl: json['profileImageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isTwoFactorEnabled: json['isTwoFactorEnabled'] as bool? ?? false,
      accountOrigin: enumValue(AccountOrigin.values, [
        'accountOrigin',
        'account_origin',
      ], AccountOrigin.legacyUnknown),
      clientStatus: enumValue(
        ClientAccountStatus.values,
        ['clientStatus', 'client_status'],
        json['isActive'] as bool? ?? true
            ? ClientAccountStatus.active
            : ClientAccountStatus.inactive,
      ),
      loginStatus: enumValue(ClientLoginStatus.values, [
        'loginStatus',
        'login_status',
      ], ClientLoginStatus.active),
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      termsAccepted: json['termsAccepted'] as bool? ?? false,
      onboardedAt: readDate(['onboardedAt', 'onboarded_at']),
      credentialsSentAt: readDate(['credentialsSentAt', 'credentials_sent_at']),
      lastLoginAt: readDate(['lastLoginAt', 'last_login_at']),
      createdAt: createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'mobile': mobile,
    'role': role.name,
    'firmId': firmId,
    'firmName': firmName,
    'profileImageUrl': profileImageUrl,
    'isActive': isActive,
    'isTwoFactorEnabled': isTwoFactorEnabled,
    'accountOrigin': accountOrigin.name,
    'clientStatus': clientStatus.name,
    'loginStatus': loginStatus.name,
    'mustChangePassword': mustChangePassword,
    'termsAccepted': termsAccepted,
    'onboardedAt': onboardedAt?.toIso8601String(),
    'credentialsSentAt': credentialsSentAt?.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
