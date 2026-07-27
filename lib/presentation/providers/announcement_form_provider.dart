import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/announcement/announcement_repository.dart';

/// State ASYNC (simpan) untuk layar Buat/Edit Pengumuman — HANYA bagian yang
/// berupa status muat/simpan ke backend. Input form interaktif (controller
/// judul/isi, jenis terpilih, toggle aktif, tanggal mulai/berakhir, gambar yang
/// dipilih) TETAP di widget `AnnouncementFormScreen`, tidak dipindah ke sini.
///
/// Yang dipindah: flag `submitting` (sedang menyimpan) + pesan error simpan,
/// beserta logika create/update + unggah gambar. Repository legacy dipakai ulang
/// via provider di `repository_providers`.
class AnnouncementFormState {
  final bool submitting;
  final String saveErrorMsg;

  const AnnouncementFormState({
    this.submitting = false,
    this.saveErrorMsg = '',
  });

  AnnouncementFormState copyWith({
    bool? submitting,
    String? saveErrorMsg,
  }) {
    return AnnouncementFormState(
      submitting: submitting ?? this.submitting,
      saveErrorMsg: saveErrorMsg ?? this.saveErrorMsg,
    );
  }
}

final announcementFormProvider =
    NotifierProvider<AnnouncementFormNotifier, AnnouncementFormState>(
      AnnouncementFormNotifier.new,
    );

/// Memindahkan logika `setState` ASYNC dari `_AnnouncementFormScreenState`.
/// Logika simpan (create/update + uploadImage) DIPINDAH APA ADANYA; nilai form
/// (judul, isi, jenis, aktif, tanggal, gambar) dikirim sebagai argumen oleh
/// widget yang tetap memegang input interaktifnya.
class AnnouncementFormNotifier extends Notifier<AnnouncementFormState> {
  @override
  AnnouncementFormState build() => const AnnouncementFormState();

  /// Kembalikan ke keadaan awal saat layar form dibuka.
  ///
  /// Provider ini BUKAN autoDispose, jadi state-nya hidup selama sesi app. Tanpa
  /// reset ini, `submitting`/`saveErrorMsg` dari pembukaan form sebelumnya ikut
  /// terbawa — itulah sebab tombol simpan pada layar Edit Pengumuman muncul
  /// dalam keadaan loading dan tak bisa ditekan.
  void reset() => state = const AnnouncementFormState();

  /// Simpan pengumuman (create atau update) lalu unggah gambar bila ada.
  /// Mengembalikan `Announcement` yang tersimpan bila sukses (widget menutup
  /// layar), atau `null` bila gagal (state → `submitting:false` + `saveErrorMsg`).
  Future<Announcement?> save({
    required bool isEdit,
    String? existingId,
    required String title,
    required String body,
    required String type,
    required String? category,
    required bool active,
    required String? startsAt,
    required String? endsAt,
    required Uint8List? imageBytes,
    required String? imageName,
  }) async {
    state = state.copyWith(submitting: true);
    final repo = ref.read(announcementRepoProvider);
    try {
      final Announcement saved;
      if (isEdit) {
        saved = await repo.update(
          existingId!,
          title: title,
          body: body.isEmpty ? null : body,
          type: type,
          category: category,
          active: active,
          startsAt: startsAt,
          endsAt: endsAt,
        );
      } else {
        saved = await repo.create(
          title: title,
          body: body.isEmpty ? null : body,
          type: type,
          category: category,
          active: active,
          startsAt: startsAt,
          endsAt: endsAt,
        );
      }
      if (imageBytes != null) {
        await repo.uploadImage(saved.id, imageBytes, imageName ?? 'banner.jpg');
      }
      // Turunkan flag juga pada jalur SUKSES. Biasanya layar langsung ditutup,
      // tapi state provider ini bertahan lintas layar — kalau dibiarkan `true`,
      // form berikutnya (mis. Edit) dibuka dengan tombol simpan terkunci loading.
      state = state.copyWith(submitting: false, saveErrorMsg: '');
      return saved;
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        saveErrorMsg: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }
}
