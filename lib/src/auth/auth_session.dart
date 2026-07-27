import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      accessTokenExpiresAt: _parseDateTime(json['accessTokenExpiresAt'] as String?),
      refreshTokenExpiresAt: _parseDateTime(json['refreshTokenExpiresAt'] as String?),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
      'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
      'user': user.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory AuthSession.fromJsonString(String value) => AuthSession.fromJson(jsonDecode(value) as Map<String, dynamic>);

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.nip,
    required this.name,
    required this.email,
    required this.roles,
    required this.authMethod,
    required this.active,
    this.officeId,
    this.entraObjectId,
    this.jabatan,
    this.mustChangePassword = false,
    this.isConnect = false,
  });

  final String id;
  final String nip;
  final String name;
  final String email;
  final List<String> roles;
  final String authMethod;
  final bool? active;
  final String? officeId;
  final String? entraObjectId;

  /// Titel jabatan untuk ditampilkan di UI (mis. "Business Head",
  /// "Marketing Office Head", "Associate II RM"). Role tetap penentu akses.
  final String? jabatan;

  /// Akun dibuat dengan password bersama/sementara (mis. seed UAT atau dibuat
  /// admin). Router memaksa layar ganti password sebelum aplikasi bisa dipakai.
  /// Hanya berlaku untuk login LOCAL — akun SSO tidak punya password lokal.
  final bool mustChangePassword;

  /// RM tagged as "Connect" by an admin — shown as a badge next to jabatan.
  final bool isConnect;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      nip: json['nip'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      officeId: json['officeId'] as String?,
      roles: (json['roles'] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
      authMethod: json['authMethod'] as String? ?? 'LOCAL',
      active: json['active'] as bool?,
      entraObjectId: json['entraObjectId'] as String?,
      jabatan: json['jabatan'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      isConnect: json['isConnect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nip': nip,
      'name': name,
      'email': email,
      'officeId': officeId,
      'roles': roles,
      'authMethod': authMethod,
      'active': active,
      'entraObjectId': entraObjectId,
      'jabatan': jabatan,
      'mustChangePassword': mustChangePassword,
      'isConnect': isConnect,
    };
  }
}
