import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Satu baris di dalam bottom banner rincian KPI.
///
/// [title] adalah identitas baris yang dicari mata lebih dulu. Untuk baris
/// pipeline itu BERARTI NAMA CUSTOMER, bukan nama broker/BUMN/RM-nya: sebuah
/// daftar pipeline tanpa nama customer tidak bisa dipakai — tidak ada yang tahu
/// "P3 senilai 1,2 M" itu milik siapa. Konteks (broker/BUMN/RM asalnya, tahap)
/// masuk ke [subtitle].
class KpiDrilldownRow {
  const KpiDrilldownRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;

  /// Tujuan ketukan (detail broker/BUMN/RM, atau pipeline-nya). Null = baris
  /// tetap tampil tapi tidak bisa ditekan — dipakai saat tujuan yang jujur
  /// memang tidak ada, mis. broker master yang tak punya pipeline di cakupan ini.
  final VoidCallback? onTap;
}

/// Bottom banner berisi daftar di balik sebuah kartu KPI (CR-06).
///
/// Isinya dirakit dari data yang SUDAH dimuat layar, jadi jumlah barisnya cocok
/// dengan angka di kartunya — itu sebabnya pola ini hanya dipakai di layar yang
/// memuat daftarnya sekaligus (Broker, BUMN). Layar dengan daftar ber-halaman
/// (Customer, RM) memakai penyaringan pada daftar utamanya, supaya paging,
/// pencarian, dan urutan tetap bekerja dan tidak ada daftar separuh jalan yang
/// menyamar sebagai daftar penuh.
Future<void> showKpiDrilldownSheet(
  BuildContext context, {
  required String title,
  required List<KpiDrilldownRow> rows,
  required String emptyMessage,
  String? subtitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceWhite,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Jumlah baris ditulis eksplisit: pembaca bisa mencocokkannya
                    // sendiri dengan angka di kartu yang barusan ditekan.
                    Text(
                      '${rows.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              Expanded(
                child: rows.isEmpty
                    ? _empty(emptyMessage)
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(
                            height: 1, thickness: 1, color: AppColors.border),
                        itemBuilder: (_, i) => _row(sheetContext, rows[i]),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _empty(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    ),
  );
}

Widget _row(BuildContext sheetContext, KpiDrilldownRow row) {
  final onTap = row.onTap;
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl, vertical: 4),
    title: Text(
      row.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    subtitle: row.subtitle == null
        ? null
        : Text(
            row.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
    trailing: row.trailing == null
        ? (onTap == null
            ? null
            : const Icon(Icons.chevron_right,
                size: 20, color: AppColors.grayStage))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.trailing!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: row.trailingColor ?? AppColors.textPrimary,
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.grayStage),
            ],
          ),
    // Sheet ditutup DULU baru berpindah: tanpa ini banner-nya tertinggal
    // menutupi halaman tujuan.
    onTap: onTap == null
        ? null
        : () {
            Navigator.of(sheetContext).pop();
            onTap();
          },
  );
}
