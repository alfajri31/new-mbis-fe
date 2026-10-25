import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../visit_rm_models.dart';

/// Kartu filter lengkap sesuai prototype M-BIS:
/// Periode kunjungan, Wilayah (Admin), Cabang (Disabled untuk RM/Pinca),
/// Nama RM (hidden untuk RM), Stage Pipeline, Kategori, Entitas BUMN,
/// Status HVC, Sumber Bisnis, COB, LOB, TOC, serta tombol Reset & Tutup.
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

  final String selectedStage;
  final ValueChanged<String?> onSelectedStageChanged;
  final String selectedKat;
  final ValueChanged<String?> onSelectedKatChanged;
  final String selectedEnt;
  final ValueChanged<String?> onSelectedEntChanged;
  final String selectedHvc;
  final ValueChanged<String?> onSelectedHvcChanged;
  final String selectedSumber;
  final ValueChanged<String?> onSelectedSumberChanged;
  final String selectedCob;
  final ValueChanged<String?> onSelectedCobChanged;
  final String selectedLob;
  final ValueChanged<String?> onSelectedLobChanged;
  final String selectedToc;
  final ValueChanged<String?> onSelectedTocChanged;

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
    required this.selectedStage,
    required this.onSelectedStageChanged,
    required this.selectedKat,
    required this.onSelectedKatChanged,
    required this.selectedEnt,
    required this.onSelectedEntChanged,
    required this.selectedHvc,
    required this.onSelectedHvcChanged,
    required this.selectedSumber,
    required this.onSelectedSumberChanged,
    required this.selectedCob,
    required this.onSelectedCobChanged,
    required this.selectedLob,
    required this.onSelectedLobChanged,
    required this.selectedToc,
    required this.onSelectedTocChanged,
    required this.branchesInScope,
    required this.rmsInBranchScope,
    required this.onReset,
    required this.onClose,
  });

  static const List<String> _allLobs = [
    'Asuransi Harta Benda',
    'Asuransi Kecelakaan Diri',
    'Asuransi Kendaraan Bermotor',
    'Asuransi Rekayasa',
  ];

  static List<String> _getTocs(String lob) {
    if (lob == 'Asuransi Kecelakaan Diri') {
      return ['PA Xtra – Personal', 'PSAKDI – Personal'];
    } else if (lob == 'Asuransi Harta Benda') {
      return ['IAR / Industrial All Risk'];
    } else if (lob == 'Asuransi Kendaraan Bermotor') {
      return ['Kendaraan Pengangkut Barang'];
    } else if (lob == 'Asuransi Rekayasa') {
      return ['CAR / Contractor All Risk'];
    }
    return [
      'CAR / Contractor All Risk',
      'IAR / Industrial All Risk',
      'Kendaraan Pengangkut Barang',
      'PA Xtra – Personal',
      'PSAKDI – Personal',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isRmOrPinca = activeRole == 'rm' || activeRole == 'pinca';
    final tocs = _getTocs(selectedLob);

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
          // 1. Periode kunjungan
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

          // 2. Kantor Wilayah (Admin only)
          if (activeRole == 'admin') ...[
            const Text(
              'Kantor Wilayah',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
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

          // 3. Cabang (disabled untuk RM & Pinca)
          const Text(
            'Cabang',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: isRmOrPinca ? 'Padang' : selectedCab,
            enabled: !isRmOrPinca,
            items: isRmOrPinca
                ? const [DropdownMenuItem(value: 'Padang', child: Text('KC Padang'))]
                : [
                    const DropdownMenuItem(value: '', child: Text('Semua Cabang')),
                    ...branchesInScope.map((b) => DropdownMenuItem(value: b, child: Text('KC $b'))),
                  ],
            onChanged: isRmOrPinca ? (_) {} : onSelectedCabChanged,
          ),
          if (isRmOrPinca) ...[
            const SizedBox(height: 4),
            Text(
              activeRole == 'rm'
                  ? 'RM hanya melihat cabangnya sendiri'
                  : 'Pinca hanya melihat cabangnya sendiri',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 10),

          // 4. Nama RM (hanya jika bukan role RM)
          if (activeRole != 'rm') ...[
            const Text(
              'Nama RM',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
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
            const SizedBox(height: 10),
          ],

          // 5. Stage Pipeline
          const Text(
            'Stage Pipeline',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedStage,
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Stage')),
              DropdownMenuItem(value: 'P3', child: Text('P3 · Prospek')),
              DropdownMenuItem(value: 'P2', child: Text('P2 · Proses')),
              DropdownMenuItem(value: 'P1', child: Text('P1 · Penerbitan')),
              DropdownMenuItem(value: 'WON', child: Text('Won')),
            ],
            onChanged: onSelectedStageChanged,
          ),
          const SizedBox(height: 10),

          // 6. Kategori
          const Text(
            'Kategori',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedKat,
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Kategori')),
              DropdownMenuItem(value: 'Perbankan', child: Text('Perbankan')),
              DropdownMenuItem(value: 'Non Perbankan', child: Text('Non Perbankan')),
            ],
            onChanged: onSelectedKatChanged,
          ),
          const SizedBox(height: 10),

          // 7. Entitas BUMN
          const Text(
            'Entitas BUMN',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedEnt,
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Entitas')),
              DropdownMenuItem(value: 'BUMN', child: Text('BUMN')),
              DropdownMenuItem(value: 'Non BUMN', child: Text('Non BUMN')),
            ],
            onChanged: onSelectedEntChanged,
          ),
          const SizedBox(height: 10),

          // 8. Status HVC
          const Text(
            'Status HVC',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedHvc,
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Status')),
              DropdownMenuItem(value: 'hvc', child: Text('HVC')),
              DropdownMenuItem(value: 'non', child: Text('Non HVC')),
            ],
            onChanged: onSelectedHvcChanged,
          ),
          const SizedBox(height: 10),

          // 9. Sumber Bisnis
          const Text(
            'Sumber Bisnis',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedSumber,
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Sumber')),
              DropdownMenuItem(value: 'DIRECT', child: Text('DIRECT')),
              DropdownMenuItem(value: 'BROKER', child: Text('BROKER')),
              DropdownMenuItem(value: 'AGEN', child: Text('AGEN')),
            ],
            onChanged: onSelectedSumberChanged,
          ),
          const SizedBox(height: 10),

          // 10. COB
          const Text(
            'COB',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedCob,
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua COB')),
              DropdownMenuItem(value: 'Asuransi Umum', child: Text('Asuransi Umum')),
            ],
            onChanged: onSelectedCobChanged,
          ),
          const SizedBox(height: 10),

          // 11. LOB
          const Text(
            'LOB',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedLob,
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua LOB')),
              ..._allLobs.map((l) => DropdownMenuItem(value: l, child: Text(l))),
            ],
            onChanged: onSelectedLobChanged,
          ),
          const SizedBox(height: 10),

          // 12. TOC
          const Text(
            'TOC',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: selectedToc,
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua TOC')),
              ...tocs.map((t) => DropdownMenuItem(value: t, child: Text(t))),
            ],
            onChanged: onSelectedTocChanged,
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
    final effectiveValue = items.any((it) => it.value == value) ? value : items.first.value as T;

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
          value: effectiveValue,
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
