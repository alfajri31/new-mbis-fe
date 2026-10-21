import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:mbis/src/config/app_config.dart';
import 'package:mbis/src/network/api_client.dart';

/// Kontrak repository bidang usaha (lapisan `data`).
abstract class BidangUsahaRepository {
  Future<List<String>> list();
}

/// Implementasi nyata: ambil daftar bidang usaha via [ApiClient].
/// Selalu melakukan request ke API /api/bidang-usaha di Mockoon port 3567 (tanpa cache).
class ApiBidangUsahaRepository implements BidangUsahaRepository {
  final ApiClient _client;

  ApiBidangUsahaRepository({ApiClient? client})
      : _client = client ??
            ApiClient(customBaseUrl: AppConfig.mockoonBaseUrl);

  @override
  Future<List<String>> list() async {
    try {
      final res = await _client.get('/api/bidang-usaha');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final items = decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
          return items;
        }
        return const [];
      } else {
        throw Exception('Gagal memuat data (HTTP ${res.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }
}

/// Mock repository untuk offline dev atau testing.
class MockBidangUsahaRepository implements BidangUsahaRepository {
  final List<String> mockItems;
  final bool shouldThrow;

  const MockBidangUsahaRepository([
    this.mockItems = const [],
    this.shouldThrow = false,
  ]);

  @override
  Future<List<String>> list() async {
    if (shouldThrow) {
      throw Exception('Mock network error');
    }
    return mockItems;
  }
}

/// Controller pengelola logika & state Bidang Usaha (lapisan `logic/controller`).
/// Berbasis [ChangeNotifier] standar Flutter (tanpa ketergantungan pada flutter_riverpod).
///
/// Memisahkan logika pemanggilan API dari tampilan UI. Menyediakan state loading,
/// error (negative case), dan data sukses.
class BidangUsahaController extends ChangeNotifier {
  final BidangUsahaRepository _repository;

  List<String> _items = const [];
  bool _isLoading = false;
  String? _error;

  BidangUsahaController({BidangUsahaRepository? repository})
      : _repository = repository ?? ApiBidangUsahaRepository();

  List<String> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Memuat daftar bidang usaha dari API tanpa cache.
  Future<void> loadBidangUsaha() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.list();
      _items = result;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _items = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memuat ulang
  Future<void> refresh() => loadBidangUsaha();
}
