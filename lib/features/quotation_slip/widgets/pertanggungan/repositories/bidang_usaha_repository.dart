import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:mbis/src/network/api_client.dart';

/// Kontrak repository bidang usaha (lapisan `data`).
abstract class BidangUsahaRepository {
  Future<List<String>> list();
}

/// Implementasi nyata: ambil daftar bidang usaha via [ApiClient].
/// Selalu melakukan request ke API /api/bidang-usaha (tanpa cache).
class ApiBidangUsahaRepository implements BidangUsahaRepository {
  final ApiClient apiClient;

  ApiBidangUsahaRepository({required this.apiClient});

  @override
  Future<List<String>> list() async {
    try {
      final res = await apiClient.get('/api/bidang-usaha');
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
  final BidangUsahaRepository repository;

  List<String> _items = const [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  BidangUsahaController({required this.repository});

  List<String> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Memuat daftar bidang usaha dari API tanpa cache.
  Future<void> loadBidangUsaha() async {
    if (_isLoading || _disposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.list();
      if (_disposed) return;
      _items = result;
      _error = null;
    } catch (e) {
      if (_disposed) return;
      _error = e.toString().replaceAll('Exception: ', '');
      _items = const [];
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Memuat ulang
  Future<void> refresh() => loadBidangUsaha();
}
