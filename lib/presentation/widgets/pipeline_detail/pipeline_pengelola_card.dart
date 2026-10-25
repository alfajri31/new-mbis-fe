import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';

/// Kartu "Informasi Pengelola" pada detail pipeline sesuai prototype.
/// Menampilkan informasi RM penanggung jawab (avatar inisial, nama, jabatan, NIP),
/// kantor wilayah, kantor cabang, serta badge & relasi grup jika entitas BUMN.
class PipelinePengelolaCard extends StatelessWidget {
  const PipelinePengelolaCard({super.key, required this.pipeline});

  final PipelineDetailModel pipeline;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'RM';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final rmName = (pipeline.rmName != null && pipeline.rmName!.trim().isNotEmpty)
        ? pipeline.rmName!.trim()
        : 'Mohammad Ridwan Majid';
    final rmJabatan = (pipeline.rmJabatan != null && pipeline.rmJabatan!.trim().isNotEmpty)
        ? pipeline.rmJabatan!.trim()
        : 'Associate II RM';
    final rmNip = (pipeline.rmNip != null && pipeline.rmNip!.trim().isNotEmpty)
        ? pipeline.rmNip!.trim()
        : '199002142016';
    final kanwil = (pipeline.kanwil != null && pipeline.kanwil!.trim().isNotEmpty)
        ? pipeline.kanwil!.trim()
        : 'Kantor Wilayah 1';

    String kc = (pipeline.kc != null && pipeline.kc!.trim().isNotEmpty)
        ? pipeline.kc!.trim()
        : 'Padang';
    if (!kc.toUpperCase().startsWith('KC ') && !kc.toUpperCase().startsWith('KANTOR CABANG ')) {
      kc = 'KC $kc';
    }

    final isBumn = pipeline.isBumn;
    final bumnRelasi = (pipeline.bumnRelasi != null && pipeline.bumnRelasi!.trim().isNotEmpty)
        ? pipeline.bumnRelasi!.trim()
        : 'Induk';
    final bumnGroup = (pipeline.bumnGroup != null && pipeline.bumnGroup!.trim().isNotEmpty)
        ? pipeline.bumnGroup!.trim()
        : (pipeline.customerName ?? 'BUMN');

    final initials = _getInitials(rmName);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Informasi Pengelola',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isBumn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blueLightBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BUMN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // RM Penanggung Jawab Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar Bulat
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.orangeMbis,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Informasi RM
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'RM Penanggung Jawab',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rmName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$rmJabatan · NIP $rmNip',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Rows
          _buildRow('Kantor Wilayah', kanwil, isLast: !isBumn && false),
          _buildRow('Kantor Cabang', kc, isLast: !isBumn),
          if (isBumn) ...[
            _buildRow('Entitas BUMN', bumnRelasi, isLast: false),
            _buildRow('Grup BUMN', bumnGroup, isLast: true),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
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
