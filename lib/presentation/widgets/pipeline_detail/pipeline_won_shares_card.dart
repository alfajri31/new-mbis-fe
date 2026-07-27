import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';

/// Co-insurance breakdown captured on a tender WON: Askrindo's own share plus
/// each leader/member and their percentage. Only shown for a WON tender.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving).
class PipelineWonSharesCard extends StatelessWidget {
  const PipelineWonSharesCard({super.key, required this.pipeline});

  final PipelineDetailModel pipeline;

  @override
  Widget build(BuildContext context) {
    final shares = pipeline.wonShares;
    // Askrindo selalu tampil paling atas dengan porsinya sendiri.
    final rows = <Widget>[];
    rows.add(_buildShareRow(
      'Askrindo',
      'ASKRINDO',
      pipeline.shareAskrindo,
      isLast: shares.isEmpty,
    ));
    for (int i = 0; i < shares.length; i++) {
      final s = shares[i];
      rows.add(_buildShareRow(
        (s.name != null && s.name!.isNotEmpty) ? s.name! : '-',
        s.partyType,
        s.percentage,
        isLast: i == shares.length - 1,
      ));
    }
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
              'Bagi Hasil (Co-Insurance)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...rows,
        ],
      ),
    );
  }

  /// One co-insurance row: name + role badge (Askrindo/Leader/Member) + share %.
  Widget _buildShareRow(String name, String? partyType, double? percentage, {required bool isLast}) {
    final type = (partyType ?? '').toUpperCase();
    final isAskrindo = type == 'ASKRINDO';
    final isLeader = type == 'LEADER';
    final badgeText = isAskrindo ? 'Askrindo' : (isLeader ? 'Leader' : 'Member');
    final badgeColor = isAskrindo
        ? AppColors.successGreen
        : (isLeader ? AppColors.primaryNavy : AppColors.grayStage);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
                child: Text(badgeText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              Text(percentage != null ? '${_trimPct(percentage)}%' : '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  /// Format a percent without trailing zeros, e.g. 50.0 -> "50", 12.5 -> "12,5".
  String _trimPct(double v) {
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s.replaceAll('.', ',');
  }
}
