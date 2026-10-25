import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/providers/repository_providers.dart';
import 'repositories/bidang_usaha_repository.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 1: Data Pemegang Polis dan Kontak Pengiriman QS
class QsPemegangPolisCard extends ConsumerStatefulWidget {
  final TextEditingController namaPolisCtrl;
  final TextEditingController alamatCtrl;
  final TextEditingController bidangUsahaCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController namaPicCtrl;
  final TextEditingController noHpPicCtrl;
  final bool dataSamaPolis;
  final TextEditingController namaTertanggungCtrl;
  final VoidCallback? onFieldChanged;
  final BidangUsahaController? bidangUsahaController;

  const QsPemegangPolisCard({
    super.key,
    required this.namaPolisCtrl,
    required this.alamatCtrl,
    required this.bidangUsahaCtrl,
    required this.emailCtrl,
    required this.namaPicCtrl,
    required this.noHpPicCtrl,
    required this.dataSamaPolis,
    required this.namaTertanggungCtrl,
    this.onFieldChanged,
    this.bidangUsahaController,
  });

  @override
  ConsumerState<QsPemegangPolisCard> createState() => _QsPemegangPolisCardState();
}

class _QsPemegangPolisCardState extends ConsumerState<QsPemegangPolisCard> {
  late final BidangUsahaController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.bidangUsahaController != null) {
      _controller = widget.bidangUsahaController!;
      _ownsController = false;
    } else {
      _controller = BidangUsahaController(
        repository: ref.read(bidangUsahaRepoProvider),
      );
      _ownsController = true;
    }
    // Selalu get langsung ke API setiap kali card/layar dibuka
    _controller.loadBidangUsaha();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.person_outline,
      title: 'Pemegang Polis',
      subtitle: 'Nama dan alamat yang tercantum di dokumen QS',
      children: [
        QsTextInputField(
          label: 'Nama Pemegang Polis',
          required: true,
          controller: widget.namaPolisCtrl,
          placeholder: 'Nama perorangan / perusahaan',
          onChanged: (_) {
            if (widget.dataSamaPolis) {
              widget.namaTertanggungCtrl.text = widget.namaPolisCtrl.text;
            }
            widget.onFieldChanged?.call();
          },
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
        ),
        QsTextAreaField(
          label: 'Alamat',
          required: true,
          controller: widget.alamatCtrl,
          placeholder: 'Alamat lengkap',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const QsLabelText('Bidang Usaha', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: widget.bidangUsahaCtrl,
              cursorColor: AppColors.orangeMbis,
              onChanged: (_) => widget.onFieldChanged?.call(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.blueInputText,
              ),
              decoration: InputDecoration(
                hintText: 'Pilih atau ketik bidang usaha',
                counterText: '',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPlaceholder,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.borderDefault, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.borderDefault, width: 1.5),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide:
                      BorderSide(color: AppColors.orangeMbis, width: 2.0),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide:
                      BorderSide(color: AppColors.redRequired, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                // 1. Loading State (Shimmer Skeletonizer)
                if (_controller.isLoading) {
                  return const _BidangUsahaSkeletonChips();
                }

                // 2. Negative Case (Error / Gagal Memuat)
                if (_controller.hasError) {
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorBannerBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.errorBannerBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.redRequired,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _controller.error ?? 'Gagal memuat bidang usaha',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.errorBannerText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _controller.loadBidangUsaha(),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 14,
                                  color: AppColors.orangeMbis,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Coba lagi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orangeMbis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 3. Empty State (tidak ada item dari response API)
                if (_controller.items.isEmpty) {
                  return const SizedBox.shrink();
                }

                // 4. Success State (Render Chips)
                final chBidang = _controller.items;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chBidang.map((chip) {
                    final isSel = widget.bidangUsahaCtrl.text == chip;
                    return QsQuickChip(
                      label: chip,
                      isSelected: isSel,
                      onTap: () {
                        widget.bidangUsahaCtrl.text = chip;
                        widget.onFieldChanged?.call();
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 1,
          color: AppColors.bgDisabled,
        ),
        const SizedBox(height: 14),
        const Text(
          'Kontak untuk pengiriman QS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyMbis,
          ),
        ),
        const SizedBox(height: 14),
        QsTextInputField(
          label: 'Email Pemegang Polis',
          controller: widget.emailCtrl,
          placeholder: 'nama@perusahaan.co.id',
          helperText:
              'Link quotation dikirim ke email ini. Wajib saat "Kirim ke Customer".',
          keyboardType: TextInputType.emailAddress,
        ),
        QsTextInputField(
          label: 'Nama PIC (opsional)',
          controller: widget.namaPicCtrl,
          placeholder: 'mis. Ibu Sari – HRD',
          helperText: 'Untuk pemegang polis perusahaan / Group.',
        ),
        QsTextInputField(
          label: 'No. HP PIC (opsional)',
          controller: widget.noHpPicCtrl,
          placeholder: '08xxxxxxxxx',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }
}

/// Widget skeleton loading shimmer untuk pilihan chip bidang usaha
class _BidangUsahaSkeletonChips extends StatelessWidget {
  const _BidangUsahaSkeletonChips();

  static const _placeholders = [
    'Loading',
    'Loading',
    'Loading',
    'Loading',
    'Loading',
  ];

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _placeholders.map((label) {
          return QsQuickChip(
            label: label,
            isSelected: false,
            onTap: () {},
          );
        }).toList(),
      ),
    );
  }
}
