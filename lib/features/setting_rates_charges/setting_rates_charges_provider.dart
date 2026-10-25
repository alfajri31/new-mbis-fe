import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import 'models/pengaturan_tarif_riwayat_model.dart';

/// State untuk modul Setting Rates & Charges.
class SettingRatesChargesState {
  final Map<String, dynamic> values;
  final List<PengaturanTarifRiwayatModel> riwayatList;
  final bool isLoadingRiwayat;
  final String? riwayatErrorMessage;
  final bool isSaving;
  final bool isResetting;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastFetchedAt;

  const SettingRatesChargesState({
    required this.values,
    this.riwayatList = const [],
    this.isLoadingRiwayat = false,
    this.riwayatErrorMessage,
    this.isSaving = false,
    this.isResetting = false,
    this.isLoading = false,
    this.errorMessage,
    this.lastFetchedAt,
  });

  SettingRatesChargesState copyWith({
    Map<String, dynamic>? values,
    List<PengaturanTarifRiwayatModel>? riwayatList,
    bool? isLoadingRiwayat,
    String? riwayatErrorMessage,
    bool clearRiwayatError = false,
    bool? isSaving,
    bool? isResetting,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastFetchedAt,
  }) {
    return SettingRatesChargesState(
      values: values ?? this.values,
      riwayatList: riwayatList ?? this.riwayatList,
      isLoadingRiwayat: isLoadingRiwayat ?? this.isLoadingRiwayat,
      riwayatErrorMessage: clearRiwayatError
          ? null
          : (riwayatErrorMessage ?? this.riwayatErrorMessage),
      isSaving: isSaving ?? this.isSaving,
      isResetting: isResetting ?? this.isResetting,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }
}

/// Notifier pengelola state pengaturan tarif, biaya, dan audit log.
class SettingRatesChargesNotifier
    extends Notifier<SettingRatesChargesState> {
  /// Field-field bertipe integer (nominal rupiah atau hari)
  static const Set<String> intFields = {
    'admPolis',
    'admMaterai',
    'admE',
    'upMax',
    'cMax',
    'c_upC',
    'c_ambulan',
    'c_pemakaman',
    'c_barang',
    'c_dokumen',
    'c_pendidikan',
    'c_repatriasi',
    'validityDays',
  };

  static const Map<String, String> fieldLabels = {
    'admPolis': 'Biaya Polis (cetak)',
    'admMaterai': 'Materai',
    'admE': 'Biaya e-Polis tambahan',
    'upMax': 'UP maksimal',
    'cPct': 'Batas C (% UP)',
    'cMax': 'Batas C maksimal',
    'discMax': 'Diskon maksimal',
    'validityDays': 'Masa Berlaku QS (Hari)',
    'p_pokok': 'Rate PA Xtra Kematian',
    'p_cacat': 'Rate PA Xtra Kematian + Cacat Tetap',
    'p_upC': 'Rate PA Xtra Perawatan / Pengobatan',
    'p_ambulan': 'Rate PA Xtra Ambulan',
    'p_pemakaman': 'Rate PA Xtra Pemakaman',
    'p_barang': 'Rate PA Xtra Barang Pribadi',
    'p_dokumen': 'Rate PA Xtra Dokumen',
    'p_pendidikan': 'Rate PA Xtra Biaya Pendidikan',
    'p_repatriasi': 'Rate PA Xtra Pemulangan Jenazah',
    'c_upC': 'Batas PA Xtra Perawatan',
    'c_ambulan': 'Batas PA Xtra Ambulan',
    'c_pemakaman': 'Batas PA Xtra Pemakaman',
    'c_barang': 'Batas PA Xtra Barang Pribadi',
    'c_dokumen': 'Batas PA Xtra Dokumen',
    'c_pendidikan': 'Batas PA Xtra Biaya Pendidikan',
    'c_repatriasi': 'Batas PA Xtra Pemulangan Jenazah',
    'rA0': 'Rate A Kelas 1',
    'rA1': 'Rate A Kelas 2',
    'rA2': 'Rate A Kelas 3',
    'rA3': 'Rate A Kelas 4',
    'rAB0': 'Rate A/B Kelas 1',
    'rAB1': 'Rate A/B Kelas 2',
    'rAB2': 'Rate A/B Kelas 3',
    'rAB3': 'Rate A/B Kelas 4',
    'rC0': 'Rate C Kelas 1',
    'rC1': 'Rate C Kelas 2',
    'rC2': 'Rate C Kelas 3',
    'rC3': 'Rate C Kelas 4',
  };

  @override
  SettingRatesChargesState build() {
    // Trigger pengambilan tarif & biaya terbaru serta riwayat perubahan dari backend API
    Future.microtask(() {
      fetchPengaturanTarif();
      fetchRiwayat();
    });

    // State awal murni kosong tanpa default value sebelum data diterima dari server
    return const SettingRatesChargesState(
      values: {},
      riwayatList: [],
      isLoading: true,
      isLoadingRiwayat: true,
    );
  }

  /// Helper untuk memetakan respon psakdi & paextra ke map state values
  Map<String, dynamic> _parseProductsMap(
    Map<String, dynamic> psakdi,
    Map<String, dynamic> paextra,
    Map<String, dynamic> baseValues,
  ) {
    final Map<String, dynamic> merged = Map<String, dynamic>.from(baseValues);

    void mapValue(String key, dynamic raw) {
      if (raw == null) return;
      if (intFields.contains(key)) {
        if (raw is num) {
          merged[key] = raw.toInt();
        } else {
          merged[key] = int.tryParse(raw.toString()) ?? raw;
        }
      } else {
        if (raw is num) {
          merged[key] = raw.toDouble();
        } else {
          merged[key] = double.tryParse(raw.toString()) ?? raw;
        }
      }
    }

    for (final entry in psakdi.entries) {
      mapValue(entry.key, entry.value);
    }
    for (final entry in paextra.entries) {
      mapValue(entry.key, entry.value);
    }
    return merged;
  }

  /// Mengambil pengaturan tarif & biaya terbaru dari backend API
  Future<void> fetchPengaturanTarif() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/api/qs/pengaturan-tarif');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final psakdi = decoded['psakdi'] as Map<String, dynamic>? ?? {};
          final paextra = decoded['paextra'] as Map<String, dynamic>? ?? {};

          final merged = _parseProductsMap(psakdi, paextra, state.values);

          state = state.copyWith(
            values: merged,
            isLoading: false,
            clearError: true,
            lastFetchedAt: DateTime.now(),
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Format respon dari server tidak sesuai format yang diharapkan.',
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Gagal memuat pengaturan tarif (Status ${res.statusCode}). Silakan coba beberapa saat lagi.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Koneksi ke server gagal: $e',
      );
    }
  }

  /// Mengambil data riwayat perubahan pengaturan tarif & biaya dari GET /api/qs/pengaturan-tarif/riwayat
  Future<void> fetchRiwayat() async {
    state = state.copyWith(isLoadingRiwayat: true, clearRiwayatError: true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/api/qs/pengaturan-tarif/riwayat');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> listJson = [];
        if (decoded is List) {
          listJson = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          listJson = decoded['data'] as List;
        }

        final items = listJson
            .map((item) => PengaturanTarifRiwayatModel.fromJson(
                item as Map<String, dynamic>))
            .toList();

        // Urutkan riwayat dari yang paling baru (changedAt descending)
        items.sort((a, b) {
          if (a.changedAt == null && b.changedAt == null) return 0;
          if (a.changedAt == null) return 1;
          if (b.changedAt == null) return -1;
          return b.changedAt!.compareTo(a.changedAt!);
        });

        state = state.copyWith(
          riwayatList: items,
          isLoadingRiwayat: false,
          clearRiwayatError: true,
        );
      } else {
        state = state.copyWith(
          isLoadingRiwayat: false,
          riwayatErrorMessage:
              'Gagal memuat riwayat perubahan (Status ${res.statusCode})',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingRiwayat: false,
        riwayatErrorMessage: 'Koneksi gagal saat memuat riwayat perubahan: $e',
      );
    }
  }

  /// Menutup pesan error pengaturan
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  /// Menutup pesan error riwayat
  void dismissRiwayatError() {
    state = state.copyWith(clearRiwayatError: true);
  }

  /// Muat ulang atau sinkronkan kembali dari server
  Future<void> reloadFromServer() async {
    await Future.wait([
      fetchPengaturanTarif(),
      fetchRiwayat(),
    ]);
  }

  /// Membangun payload request PUT /api/qs/pengaturan-tarif sesuai format API
  Map<String, dynamic> buildPutPayload(Map<String, dynamic> currentValues) {
    int intVal(String key) {
      final v = currentValues[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    num numVal(String key) {
      final v = currentValues[key];
      if (v is num) return v;
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    final psakdiMap = <String, dynamic>{
      'productCode': 'psakdi',
      'admPolis': intVal('admPolis'),
      'admMaterai': intVal('admMaterai'),
      'admE': intVal('admE'),
      'upMax': intVal('upMax'),
      'cPct': numVal('cPct'),
      'cMax': intVal('cMax'),
      'discMax': numVal('discMax'),
      'rA0': numVal('rA0'),
      'rA1': numVal('rA1'),
      'rA2': numVal('rA2'),
      'rA3': numVal('rA3'),
      'rAB0': numVal('rAB0'),
      'rAB1': numVal('rAB1'),
      'rAB2': numVal('rAB2'),
      'rAB3': numVal('rAB3'),
      'rC0': numVal('rC0'),
      'rC1': numVal('rC1'),
      'rC2': numVal('rC2'),
      'rC3': numVal('rC3'),
    };

    final paextraMap = <String, dynamic>{
      'productCode': 'paextra',
      'admPolis': intVal('admPolis'),
      'admMaterai': intVal('admMaterai'),
      'admE': intVal('admE'),
      'upMax': intVal('upMax'),
      'cPct': numVal('cPct'),
      'cMax': intVal('cMax'),
      'discMax': numVal('discMax'),
      'p_pokok': numVal('p_pokok'),
      'p_cacat': numVal('p_cacat'),
      'p_upC': numVal('p_upC'),
      'p_ambulan': numVal('p_ambulan'),
      'p_pemakaman': numVal('p_pemakaman'),
      'p_barang': numVal('p_barang'),
      'p_dokumen': numVal('p_dokumen'),
      'p_pendidikan': numVal('p_pendidikan'),
      'p_repatriasi': numVal('p_repatriasi'),
      'c_upC': intVal('c_upC'),
      'c_ambulan': intVal('c_ambulan'),
      'c_pemakaman': intVal('c_pemakaman'),
      'c_barang': intVal('c_barang'),
      'c_dokumen': intVal('c_dokumen'),
      'c_pendidikan': intVal('c_pendidikan'),
      'c_repatriasi': intVal('c_repatriasi'),
    };

    return {
      'products': [psakdiMap, paextraMap],
    };
  }

  /// Simpan pengaturan ke backend via PUT /api/qs/pengaturan-tarif dan catat diff audit log
  Future<({bool success, String message, List<String> changedFields})> save(
    Map<String, dynamic> submittedValues, {
    String by = 'UW',
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    final List<String> changedFields = [];
    for (final key in fieldLabels.keys) {
      final current = state.values[key];
      final submitted = submittedValues[key] ?? current;

      if (submitted != null && current != null && submitted.toString() != current.toString()) {
        final label = fieldLabels[key] ?? key;
        changedFields.add(label);
      }
    }

    final mergedValues =
        Map<String, dynamic>.from(state.values)..addAll(submittedValues);
    final payload = buildPutPayload(mergedValues);

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.put(
        '/api/qs/pengaturan-tarif',
        body: payload,
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        Map<String, dynamic> finalValues = mergedValues;

        // Parsing respon balikan dari PUT server (psakdi & paextra)
        if (res.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(res.body);
            if (decoded is Map<String, dynamic>) {
              final psakdi = decoded['psakdi'] as Map<String, dynamic>? ?? {};
              final paextra = decoded['paextra'] as Map<String, dynamic>? ?? {};
              finalValues = _parseProductsMap(psakdi, paextra, mergedValues);
            }
          } catch (_) {}
        }

        state = state.copyWith(
          values: finalValues,
          isSaving: false,
          clearError: true,
          lastFetchedAt: DateTime.now(),
        );

        // Sinkronisasi riwayat perubahan terbaru dari server
        fetchRiwayat();

        return (
          success: true,
          message: changedFields.isNotEmpty
              ? 'Pengaturan berhasil disimpan (${changedFields.length} perubahan)'
              : 'Pengaturan berhasil disimpan',
          changedFields: changedFields,
        );
      } else {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Gagal menyimpan ke server (Status ${res.statusCode})',
        );
        return (
          success: false,
          message: 'Gagal menyimpan pengaturan: Status ${res.statusCode}',
          changedFields: changedFields,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Koneksi gagal saat menyimpan pengaturan: $e',
      );
      return (
        success: false,
        message: 'Koneksi gagal: $e',
        changedFields: changedFields,
      );
    }
  }

  /// Mengembalikan pengaturan tarif & biaya ke default sistem melalui POST /api/qs/pengaturan-tarif/kembalikan-default
  Future<({bool success, String message, Map<String, dynamic>? data})>
      kembalikanDefault({
    String by = 'UW',
  }) async {
    state = state.copyWith(isResetting: true, clearError: true);
    try {
      final client = ref.read(apiClientProvider);
      final res =
          await client.post('/api/qs/pengaturan-tarif/kembalikan-default');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          Map<String, dynamic> data = decoded;
          if (decoded['data'] is Map<String, dynamic>) {
            data = decoded['data'] as Map<String, dynamic>;
          }
          final psakdi = (data['psakdi'] as Map<String, dynamic>?) ?? {};
          final paextra = (data['paextra'] as Map<String, dynamic>?) ?? {};

          final merged = _parseProductsMap(psakdi, paextra, state.values);

          state = state.copyWith(
            values: merged,
            isResetting: false,
            clearError: true,
            lastFetchedAt: DateTime.now(),
          );

          // Sinkronisasi riwayat perubahan terbaru dari server
          fetchRiwayat();

          return (
            success: true,
            message: 'Pengaturan tarif & biaya berhasil dikembalikan ke default',
            data: merged,
          );
        } else {
          state = state.copyWith(
            isResetting: false,
            errorMessage:
                'Format respon dari server tidak sesuai format yang diharapkan.',
          );
          return (
            success: false,
            message: 'Format respon dari server tidak sesuai.',
            data: null,
          );
        }
      } else {
        state = state.copyWith(
          isResetting: false,
          errorMessage:
              'Gagal mengembalikan ke default (Status ${res.statusCode})',
        );
        return (
          success: false,
          message: 'Gagal mengembalikan pengaturan: Status ${res.statusCode}',
          data: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isResetting: false,
        errorMessage: 'Koneksi gagal saat mengembalikan ke default: $e',
      );
      return (
        success: false,
        message: 'Koneksi gagal: $e',
        data: null,
      );
    }
  }
}

/// Provider Riverpod untuk modul Setting Rates & Charges.
final settingRatesChargesProvider =
    NotifierProvider<SettingRatesChargesNotifier, SettingRatesChargesState>(
  SettingRatesChargesNotifier.new,
);
