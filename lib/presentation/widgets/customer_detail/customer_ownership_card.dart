import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';
import 'customer_info_row.dart';

/// Shows the responsible RM (assignedRm) and where the customer came from —
/// an agent who recorded it, or an RM directly.
/// Murni presentational — diekstrak dari `customer_detail_screen.dart`
/// (behavior-preserving).
class CustomerOwnershipCard extends StatelessWidget {
  const CustomerOwnershipCard({super.key, required this.customer});

  final CustomerDetailModel customer;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final isAgent = c.sourceType == 'AGENT';
    final sourceLabel = (c.sourceName != null && c.sourceName!.isNotEmpty)
        ? (isAgent ? 'Agen: ${c.sourceName}' : 'RM: ${c.sourceName}')
        : '-';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomerInfoRow(
            icon: Icons.account_circle_outlined,
            label: 'RM Penanggung Jawab',
            value: (c.assignedRmName != null && c.assignedRmName!.isNotEmpty)
                ? c.assignedRmName!
                : '-',
          ),
          const Divider(height: 20, color: AppColors.border),
          CustomerInfoRow(
            icon: isAgent
                ? Icons.handshake_outlined
                : Icons.person_pin_outlined,
            label: 'Sumber Data',
            value: sourceLabel,
          ),
        ],
      ),
    );
  }
}
