import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/agent/agent_repository.dart';

const Object _keep = Object();

/// A phase-1 onboarding document requirement. [condition] gates visibility:
/// null = always shown; 'domicile' = only when domicile differs from KTP;
/// 'exAgent' = only when the candidate was an agent elsewhere.
///
/// (Dulu `_DocDef` privat di `ajukan_agen_screen.dart`; dipindah ke sini agar
/// notifier & layar sama-sama bisa memakainya saat memuat checklist dari config.)
class AjukanDocDef {
  final String code;
  final String label;
  final bool required;
  final String? condition;
  const AjukanDocDef(this.code, this.label,
      {this.required = false, this.condition});
}

/// State ASYNC (data/loading) untuk layar Ajukan Agen/TPM — HANYA bagian yang
/// dimuat dari backend atau berupa status simpan. Input form interaktif
/// (controller, jenis/bank/gender terpilih, tanggal lahir, toggle domisili/
/// ex-agen, map dokumen ter-upload) TETAP di widget `AjukanAgenScreen`.
///
/// Yang dipindah: template dokumen (download), config wajib-tidaknya field,
/// checklist dokumen dari config, opsi jenis kelamin (param GENDER), kode
/// dokumen yang sudah ada di server (mode edit), serta flag `busy` saat simpan.
class AjukanAgenState {
  final Map<String, AgentTemplateItem> templates; // code → template (tombol unduh)
  final Map<String, bool> fieldRequired; // field code → wajib (admin config)
  final List<AjukanDocDef>? configDocs; // checklist dari admin config (null = fallback)
  // Opsi jenis kelamin: param GENDER (admin-editable); fallback bila belum termuat.
  final List<String> genderOptions;
  final Set<String> existingDocCodes; // dokumen yang sudah tersimpan (mode edit)
  final bool busy; // sedang menyimpan/submit

  const AjukanAgenState({
    this.templates = const {},
    this.fieldRequired = const {},
    this.configDocs,
    this.genderOptions = const ['Laki-laki', 'Perempuan'],
    this.existingDocCodes = const {},
    this.busy = false,
  });

  AjukanAgenState copyWith({
    Map<String, AgentTemplateItem>? templates,
    Map<String, bool>? fieldRequired,
    Object? configDocs = _keep,
    List<String>? genderOptions,
    Set<String>? existingDocCodes,
    bool? busy,
  }) {
    return AjukanAgenState(
      templates: templates ?? this.templates,
      fieldRequired: fieldRequired ?? this.fieldRequired,
      configDocs: configDocs == _keep
          ? this.configDocs
          : configDocs as List<AjukanDocDef>?,
      genderOptions: genderOptions ?? this.genderOptions,
      existingDocCodes: existingDocCodes ?? this.existingDocCodes,
      busy: busy ?? this.busy,
    );
  }
}

final ajukanAgenProvider =
    NotifierProvider<AjukanAgenNotifier, AjukanAgenState>(
      AjukanAgenNotifier.new,
    );

/// Memindahkan logika `setState` ASYNC dari `_AjukanAgenScreenState`. Tiap
/// metode DIPINDAH APA ADANYA (muat template, muat config, muat dokumen
/// eksisting, simpan). Repository legacy dipakai ulang lewat provider di
/// `repository_providers`; sesi dibawa `apiClientProvider` — tak perlu context.
class AjukanAgenNotifier extends Notifier<AjukanAgenState> {
  @override
  AjukanAgenState build() => const AjukanAgenState();

  /// Dipanggil sekali dari initState layar (post-frame). Reset ke baseline
  /// bersih (provider global bisa membawa sisa sesi layar sebelumnya) lalu muat
  /// template + config. Menggantikan post-frame `_loadTemplates()`+`_loadConfig()`.
  void start() {
    state = const AjukanAgenState();
    loadTemplates();
    loadConfig();
  }

  Future<void> loadTemplates() async {
    try {
      final items = await ref.read(agentRepoProvider).getAgentTemplates();
      state = state.copyWith(
        templates: {for (final t in items) t.code: t},
      );
    } catch (_) {
      // templates are optional; ignore load failure
    }
  }

  /// Loads admin-configured field requiredness + registration doc checklist.
  Future<void> loadConfig() async {
    try {
      final repo = ref.read(masterDataRepoProvider);
      final fields =
          await repo.getParameters(category: 'AGENT_FIELD', activeOnly: true);
      final docs =
          await repo.getParameters(category: 'AGENT_DOC_REG', activeOnly: true);
      final gender =
          await repo.getParameters(category: 'GENDER', activeOnly: true);
      state = state.copyWith(
        fieldRequired: {
          for (final p in fields) p.paramKey: (p.numericValue ?? 0) >= 1,
        },
        configDocs: docs
            .map((p) => AjukanDocDef(p.paramKey, p.paramValue,
                required: (p.numericValue ?? 0) >= 1,
                condition: _conditionFor(p.paramKey)))
            .toList(),
        genderOptions: gender.isNotEmpty
            ? gender.map((p) => p.paramValue).toList()
            : state.genderOptions,
      );
    } catch (_) {
      // config optional; keep built-in defaults on failure
    }
  }

  String? _conditionFor(String code) {
    if (code == 'SK_DOMISILI') return 'domicile';
    if (code == 'SURAT_PENGUNDURAN_DIRI') return 'exAgent';
    return null;
  }

  /// Muat kode dokumen yang sudah tersimpan di server (mode edit). Mengembalikan
  /// himpunan kode agar layar dapat menyalakan toggle domisili/ex-agen (input
  /// yang tetap di widget). Dokumen opsional; gagal muat diabaikan (return {}).
  Future<Set<String>> loadExistingDocs(String agentId) async {
    try {
      final docs = await ref.read(agentRepoProvider).getDocuments(agentId);
      final codes = docs.map((d) => d.docType).toSet();
      state = state.copyWith(existingDocCodes: codes);
      return codes;
    } catch (_) {
      // documents are optional; ignore load failure
      return const <String>{};
    }
  }

  /// Simpan calon (create/update) + unggah dokumen terpilih + (opsional) submit.
  /// Logika `_save` dipindah apa adanya; flag `busy` dikelola di sini. Nilai form
  /// (dari controller/pilihan di widget) diteruskan sebagai parameter; [uploads]
  /// = daftar (docType, bytes, fileName) dari map upload di widget.
  ///
  /// Mengembalikan `null` bila sukses (layar akan pop — `busy` sengaja tetap
  /// true, seperti perilaku lama), atau pesan error bila gagal (`busy` → false).
  Future<String?> save({
    required bool isEdit,
    required String? existingId,
    required bool submit,
    required String name,
    required String type,
    required String phone,
    required String email,
    String? npwp,
    String? bankName,
    String? accountNumber,
    String? ktpNumber,
    String? birthDate,
    String? gender,
    String? ktpAddress,
    String? ktpProvince,
    String? ktpCity,
    String? ktpDistrict,
    String? ktpSubdistrict,
    String? ktpRt,
    String? ktpRw,
    String? ktpPostalCode,
    String? domicileAddress,
    String? domicileProvince,
    String? domicileCity,
    String? domicileDistrict,
    String? domicileSubdistrict,
    String? domicileRt,
    String? domicileRw,
    String? domicilePostalCode,
    required List<(String, List<int>, String)> uploads,
  }) async {
    state = state.copyWith(busy: true);
    final repo = ref.read(agentRepoProvider);
    try {
      String agentId;
      if (isEdit) {
        await repo.updateAgent(
          existingId!,
          name: name,
          type: type,
          phone: phone,
          email: email,
          npwp: npwp,
          bankName: bankName,
          accountNumber: accountNumber,
          ktpNumber: ktpNumber,
          birthDate: birthDate,
          gender: gender,
          ktpAddress: ktpAddress,
          ktpProvince: ktpProvince,
          ktpCity: ktpCity,
          ktpDistrict: ktpDistrict,
          ktpSubdistrict: ktpSubdistrict,
          ktpRt: ktpRt,
          ktpRw: ktpRw,
          ktpPostalCode: ktpPostalCode,
          domicileAddress: domicileAddress,
          domicileProvince: domicileProvince,
          domicileCity: domicileCity,
          domicileDistrict: domicileDistrict,
          domicileSubdistrict: domicileSubdistrict,
          domicileRt: domicileRt,
          domicileRw: domicileRw,
          domicilePostalCode: domicilePostalCode,
        );
        agentId = existingId;
      } else {
        final created = await repo.createAgent(
          name: name,
          type: type,
          phone: phone,
          email: email,
          npwp: npwp,
          bankName: bankName,
          accountNumber: accountNumber,
          ktpNumber: ktpNumber,
          birthDate: birthDate,
          gender: gender,
          ktpAddress: ktpAddress,
          ktpProvince: ktpProvince,
          ktpCity: ktpCity,
          ktpDistrict: ktpDistrict,
          ktpSubdistrict: ktpSubdistrict,
          ktpRt: ktpRt,
          ktpRw: ktpRw,
          ktpPostalCode: ktpPostalCode,
          domicileAddress: domicileAddress,
          domicileProvince: domicileProvince,
          domicileCity: domicileCity,
          domicileDistrict: domicileDistrict,
          domicileSubdistrict: domicileSubdistrict,
          domicileRt: domicileRt,
          domicileRw: domicileRw,
          domicilePostalCode: domicilePostalCode,
        );
        agentId = created.id;
      }

      for (final u in uploads) {
        await repo.uploadDocument(agentId,
            docType: u.$1, fileBytes: u.$2, fileName: u.$3);
      }

      if (submit) {
        await repo.submitForApproval(agentId);
      }
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return e.toString().replaceAll('Exception: ', '');
    }
  }
}
