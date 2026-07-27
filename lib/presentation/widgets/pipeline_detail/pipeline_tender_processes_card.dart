import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../screens/tender_status_screen.dart' show tenderLabel;

/// Tender process timeline as defined on the pipeline (selected + auto-added
/// mandatory steps). The active step is `tenderCurrentSeq`; earlier ones are
/// marked done.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving).
class PipelineTenderProcessesCard extends StatelessWidget {
  const PipelineTenderProcessesCard({super.key, required this.pipeline});

  final PipelineDetailModel pipeline;

  @override
  Widget build(BuildContext context) {
    final steps = [...pipeline.tenderProcesses]..sort((a, b) => a.seq.compareTo(b.seq));
    final cur = pipeline.tenderCurrentSeq ?? 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              'Proses Tender',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < steps.length; i++) _buildTenderProcessRow(steps[i], i, cur, i == steps.length - 1),
        ],
      ),
    );
  }

  Widget _buildTenderProcessRow(PipelineTenderModel s, int i, int cur, bool isLast) {
    final done = i < cur;
    final active = i == cur;
    // Lengkap = KEDUA tanggal terisi. Sebelumnya cukup salah satu, jadi baris
    // yang hanya punya tanggal mulai tampil "1 Jul 2026 – -" seolah beres.
    final hasDates = (s.startDate != null && s.startDate!.isNotEmpty) && (s.endDate != null && s.endDate!.isNotEmpty);
    final range = hasDates
        ? '${AppFormat.dateOnly(s.startDate)} – ${AppFormat.dateOnly(s.endDate)}'
        : 'Tanggal belum diisi';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle
                    : (active ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                size: 20,
                color: done
                    ? AppColors.successGreen
                    : (active ? AppColors.primaryNavy : AppColors.grayStage),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${tenderLabel(s.processType)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.bold : FontWeight.w500,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    // Tanggal kosong = penanda (oranye tebal), bukan teks abu
                    // yang mudah dikira keterangan biasa.
                    Text(range,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: hasDates ? FontWeight.normal : FontWeight.bold,
                            color: hasDates ? AppColors.textSecondary : AppColors.secondaryOrange)),
                  ],
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: BorderRadius.circular(100)),
                  child: const Text('aktif',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
