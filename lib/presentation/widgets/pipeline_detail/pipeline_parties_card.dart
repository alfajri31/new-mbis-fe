import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';

/// Co-parties (KSO/JO/JV/QQ/Cabang) — the >=2 badan hukum that joined this
/// kerja sama. Shown only when the pipeline actually has parties.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving).
class PipelinePartiesCard extends StatelessWidget {
  const PipelinePartiesCard({super.key, required this.pipeline});

  final PipelineDetailModel pipeline;

  @override
  Widget build(BuildContext context) {
    final parties = pipeline.parties;
    final ks = (pipeline.statusKerjaSama != null && pipeline.statusKerjaSama!.isNotEmpty)
        ? pipeline.statusKerjaSama!
        : 'Kerja Sama';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pihak Kerja Sama',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: BorderRadius.circular(100)),
                  child: Text(ks,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < parties.length; i++) _buildPartyRow(parties[i], i, i == parties.length - 1),
        ],
      ),
    );
  }

  Widget _buildPartyRow(PipelinePartyModel p, int i, bool isLast) {
    final name = (p.customerName != null && p.customerName!.isNotEmpty) ? p.customerName! : '-';
    final entity = (p.legalEntity != null && p.legalEntity!.isNotEmpty) ? p.legalEntity! : null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (entity != null) ...[
                      const SizedBox(height: 2),
                      Text(entity, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
