import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/auth/auth_session.dart';

/// Unit test serialisasi sesi autentikasi. Model ini disimpan ke secure storage
/// lalu dibaca lagi saat aplikasi dibuka, jadi round-trip JSON-nya harus utuh —
/// kalau tidak, pengguna terlempar ke layar login tanpa sebab yang jelas.
void main() {
  Map<String, dynamic> sessionJson({Map<String, dynamic>? user, Map<String, dynamic>? extra}) => {
        'accessToken': 'access-123',
        'refreshToken': 'refresh-456',
        'accessTokenExpiresAt': '2026-07-23T10:00:00.000Z',
        'refreshTokenExpiresAt': '2026-08-23T10:00:00.000Z',
        'user': {
          'id': 'U-1',
          'nip': '12345',
          'name': 'Budi',
          'email': 'budi@mbis.local',
          'roles': ['RM'],
          ...?user,
        },
        ...?extra,
      };

  group('AuthSession.fromJson', () {
    test('memetakan token dan waktu kedaluwarsa', () {
      final session = AuthSession.fromJson(sessionJson());

      expect(session.accessToken, 'access-123');
      expect(session.refreshToken, 'refresh-456');
      expect(session.accessTokenExpiresAt, DateTime.parse('2026-07-23T10:00:00.000Z'));
      expect(session.refreshTokenExpiresAt, DateTime.parse('2026-08-23T10:00:00.000Z'));
      expect(session.user.nip, '12345');
    });

    test('waktu kedaluwarsa null atau kosong tidak menggagalkan parsing', () {
      final session = AuthSession.fromJson(sessionJson(extra: {
        'accessTokenExpiresAt': null,
        'refreshTokenExpiresAt': '',
      }));

      expect(session.accessTokenExpiresAt, isNull);
      expect(session.refreshTokenExpiresAt, isNull);
    });

    test('tanggal tak terbaca menjadi null, bukan melempar exception', () {
      // Lebih baik kehilangan info kedaluwarsa daripada sesi gagal dimuat total.
      final session = AuthSession.fromJson(sessionJson(extra: {
        'accessTokenExpiresAt': 'bukan-tanggal',
      }));

      expect(session.accessTokenExpiresAt, isNull);
    });

    test('refreshToken opsional', () {
      final session = AuthSession.fromJson(sessionJson(extra: {'refreshToken': null}));

      expect(session.refreshToken, isNull);
      expect(session.accessToken, 'access-123');
    });
  });

  group('AuthUser.fromJson', () {
    test('nilai default diterapkan saat field tidak dikirim', () {
      final session = AuthSession.fromJson(sessionJson());

      expect(session.user.authMethod, 'LOCAL');
      expect(session.user.mustChangePassword, isFalse);
      expect(session.user.isConnect, isFalse);
      expect(session.user.active, isNull);
      expect(session.user.officeId, isNull);
    });

    test('mustChangePassword terbaca benar saat akun masih memakai password awal', () {
      // Aturan SIT: akun dengan password awal bersama dipaksa mengganti password
      // sebelum aplikasi bisa dipakai. Flag ini yang memicu alur tersebut.
      final session = AuthSession.fromJson(sessionJson(user: {'mustChangePassword': true}));

      expect(session.user.mustChangePassword, isTrue);
    });

    test('roles kosong bila tidak dikirim, bukan null', () {
      final session = AuthSession.fromJson(sessionJson(user: {'roles': null}));

      expect(session.user.roles, isEmpty);
    });

    test('roles selalu menjadi List<String> walau elemennya bukan string', () {
      final session = AuthSession.fromJson(sessionJson(user: {
        'roles': ['RM', 'BM'],
      }));

      expect(session.user.roles, ['RM', 'BM']);
      expect(session.user.roles, isA<List<String>>());
    });
  });

  group('round-trip', () {
    test('toJson lalu fromJson menghasilkan sesi yang setara', () {
      final original = AuthSession.fromJson(sessionJson(user: {
        'officeId': 'OFF-1',
        'jabatan': 'Relationship Manager',
        'isConnect': true,
        'active': true,
      }));

      final restored = AuthSession.fromJson(original.toJson());

      expect(restored.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.accessTokenExpiresAt, original.accessTokenExpiresAt);
      expect(restored.user.id, original.user.id);
      expect(restored.user.roles, original.user.roles);
      expect(restored.user.officeId, 'OFF-1');
      expect(restored.user.jabatan, 'Relationship Manager');
      expect(restored.user.isConnect, isTrue);
      expect(restored.user.active, isTrue);
    });

    test('round-trip lewat string bertahan (jalur secure storage)', () {
      final original = AuthSession.fromJson(sessionJson());

      final restored = AuthSession.fromJsonString(original.toJsonString());

      expect(restored.accessToken, original.accessToken);
      expect(restored.user.name, 'Budi');
      expect(restored.user.roles, ['RM']);
    });
  });
}
