import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../visit_rm_models.dart';

/// Kartu filter tanggal, periode cepat, kanwil, cabang, dan RM
class VisitRmFilterCard extends StatelessWidget {
  final String quickPeriod;
  final ValueChanged<String> onQuickPeriodChanged;
  final List<Map<String, String>> quickPeriodOptions;

  final String customDari;
  final ValueChanged<String> onCustomDariChanged;
  final String customSampai;
  final ValueChanged<String> onCustomSampaiChanged;

  final String activeRole;
  final String selectedWil;
  final ValueChanged<String?> onSelectedWilChanged;
  final String selectedCab;
  final ValueChanged<String?> onSelectedCabChanged;
  final String selectedRm;
  final ValueChanged<String?> onSelectedRmChanged;

  final List<String> branchesInScope;
  final List<RmModel> rmsInBranchScope;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const VisitRmFilterCard({
    super.key,
    required this.quickPeriod,
    required this.onQuickPeriodChanged,
    required this.quickPeriodOptions,
    required this.customDari,
    required this.onCustomDariChanged,
    required this.customSampai,
    required this.onCustomSampaiChanged,
    required this.activeRole,
    required this.selectedWil,
    required this.onSelectedWilChanged,
    required this.selectedCab,
    required this.onSelectedCabChanged,
    required this.selectedRm,
    required this.onSelectedRmChanged,
    required this.branchesInScope,
    required this.rmsInBranchScope,
    required this.onReset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period quick pills
          const Text(
            'Periode kunjungan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: quickPeriodOptions.map((opt) {
              final isSelected = opt['id'] == quickPeriod;
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                onSelected: (val) {
                  if (val) onQuickPeriodChanged(opt['id']!);
                },
                selectedColor: AppColors.navyMbis,
                backgroundColor: AppColors.surfaceWhite,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.surfaceWhite : AppColors.textDark,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            }).toList(),
          ),

          // Custom date pickers if 'custom'
          if (quickPeriod == 'custom') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dari', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      _buildDateField(
                        context: context,
                        value: customDari,
                        onChanged: onCustomDariChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sampai', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      _buildDateField(
                        context: context,
                        value: customSampai,
                        onChanged: onCustomSampaiChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Wilayah Dropdown (Admin only)
          if (activeRole == 'admin') ...[
            const Text(
              'Kantor Wilayah',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 4),
            _buildDropdown<String>(
              value: selectedWil,
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua Kanwil')),
                ...kDefaultKanwils.map((k) => DropdownMenuItem(value: k.id, child: Text(k.name))),
              ],
              onChanged: onSelectedWilChanged,
            ),
            const SizedBox(height: 10),
          ],

          // Cabang Dropdown (Admin & Pinwil)
          if (activeRole != 'pinca') ...[
            const Text(
              'Kantor Cabang',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 4),
            _buildDropdown<String>(
              value: selectedCab,
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua Cabang')),
                ...branchesInScope.map((b) => DropdownMenuItem(value: b, child: Text('KC $b'))),
              ],
              onChanged: onSelectedCabChanged,
            ),
            const SizedBox(height: 10),
          ],

          // RM Dropdown (all roles)
          const Text(
            'Nama RM',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedRm,
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua RM')),
              ...rmsInBranchScope.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text('${r.nama} · ${r.cab}'),
                  )),
            ],
            onChanged: onSelectedRmChanged,
          ),
          const SizedBox(height: 16),

          // Action buttons: Reset & Tutup
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onReset,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderDefault, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: AppColors.textLabel,
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyMbis,
                      foregroundColor: AppColors.surfaceWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required BuildContext context,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () async {
          final parts = value.split('-');
          final initial = parts.length == 3
              ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
              : DateTime(2026, 9, 23);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) {
            final y = picked.year.toString().padLeft(4, '0');
            final m = picked.month.toString().padLeft(2, '0');
            final d = picked.day.toString().padLeft(2, '0');
            onChanged('$y-$m-$d');
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              VisitRmHelpers.formatIndoDate(value),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.iconDropdown),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceWhite : AppColors.bgDisabled,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.iconDropdown),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.textDark : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
