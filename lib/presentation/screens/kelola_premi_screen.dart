import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/repository_providers.dart';
import '../../src/admin/policy_repository.dart';
import '../providers/kelola_premi_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/state_views.dart';
import '../widgets/max_width_body.dart';
import '../widgets/dispose_callback.dart';
import '../../src/network/api_error.dart';
import '../../utils/input_formatters.dart';

/// Admin/PJD "Kelola Premi & Komisi": lists issued policies and lets the admin
/// record premi payments. Each payment releases the agent commission tranche
/// (GET/POST /api/admin/policies).
class KelolaPremiScreen extends ConsumerStatefulWidget {
  const KelolaPremiScreen({super.key});

  @override
  ConsumerState<KelolaPremiScreen> createState() => _KelolaPremiScreenState();
}

/// Status filter for the premi list.
enum _PremiFilter { all, unpaid, paid }

class _KelolaPremiScreenState extends ConsumerState<KelolaPremiScreen> {
  // Filter UI (tetap di widget; client-side, tak menyentuh backend).
  String _query = '';
  _PremiFilter _filter = _PremiFilter.all;

  // Sekali-per-kunjungan: meniru `_future ??= ...` lama. `didChangeDependencies`
  // bisa dipanggil >1x per kunjungan, tapi load hanya dipicu sekali; kunjungan
  // baru = State baru = flag reset = data segar (provider yang persist tak jadi
  // basi antar-kunjungan).
  bool _startedLoad = false;

  // DATA/LOADING daftar polis dikelola KelolaPremiNotifier. Getter memproksinya
  // agar kode build/FutureBuilder di bawah tetap memakai nama lama tanpa diubah.
  KelolaPremiNotifier get _notifier => ref.read(kelolaPremiProvider.notifier);
  Future<List<AdminPolicyModel>>? get _future =>
      ref.read(kelolaPremiProvider).future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loader ber-FutureBuilder: pemicu tetap di sini (sinkron, sebelum build
    // pertama) agar future non-null sejak awal dan tak ada flash error.
    if (_startedLoad) return;
    _startedLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  void _reload() => _notifier.reload();

  /// Applies the search query (policy no / customer / agent) and status filter.
  List<AdminPolicyModel> _applyFilters(List<AdminPolicyModel> all) {
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      final matchesQuery =
          q.isEmpty ||
          p.policyNumber.toLowerCase().contains(q) ||
          p.customerName.toLowerCase().contains(q) ||
          (p.agentName?.toLowerCase().contains(q) ?? false);
      final matchesStatus = switch (_filter) {
        _PremiFilter.all => true,
        _PremiFilter.unpaid => !p.lunas,
        _PremiFilter.paid => p.lunas,
      };
      return matchesQuery && matchesStatus;
    }).toList();
  }

  Future<void> _openDetail(AdminPolicyModel p) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PolicyPaymentScreen(
          repo: ref.read(adminPolicyRepoProvider),
          policy: p,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat future berubah
    // (mis. setelah reload). Menggantikan setState lama.
    ref.watch(kelolaPremiProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Kelola Premi & Komisi'),
      body: MaxWidthBody(
        child: FutureBuilder<List<AdminPolicyModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ErrorStateView(
                message: 'Gagal memuat daftar polis',
                onRetry: () async => _reload(),
              );
            }
            final policies = snapshot.data!;
            if (policies.isEmpty) {
              return const EmptyStateView(
                icon: Icons.description_outlined,
                title: 'Belum ada polis',
                subtitle: 'Polis muncul di sini setelah pipeline ditandai WON.',
              );
            }
            final filtered = _applyFilters(policies);
            return Column(
              children: [
                _buildSearch(),
                _buildFilterChips(),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.search_off,
                          title: 'Tidak ada polis cocok',
                          subtitle: 'Coba ubah kata kunci atau filter.',
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryNavy,
                          onRefresh: () async => _reload(),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            children: [
                              const Text(
                                'Catat pembayaran premi nasabah. Tiap pembayaran melepas komisi agen secara proporsional.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ...filtered.map(_buildPolicyCard),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TextField(
        style: AppInput.fieldText,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Cari no. polis, nasabah, atau agen',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceWhite,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    Widget chip(String label, _PremiFilter value) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _filter = value),
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primaryNavy : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surfaceWhite,
          selectedColor: AppColors.primaryNavy.withValues(alpha: 0.12),
          side: BorderSide(
            color: selected ? AppColors.primaryNavy : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip('Semua', _PremiFilter.all),
            chip('Belum Lunas', _PremiFilter.unpaid),
            chip('Lunas', _PremiFilter.paid),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(AdminPolicyModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: () => _openDetail(p),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.policyNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(p.lunas),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.grayStage,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      p.agentName ?? 'Tanpa agen (tidak ada komisi)',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.agentName != null
                            ? AppColors.textSecondary
                            : AppColors.grayStage,
                        fontStyle: p.agentName != null
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.grayBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      p.lunas ? AppColors.successGreen : AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${rupiah(p.totalPaid)} / ${rupiah(p.premiGross)} terbayar',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool lunas) {
    final color = lunas ? AppColors.successGreen : AppColors.secondaryOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        lunas ? 'Lunas' : 'Belum Lunas',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// Rupiah formatter shared within this screen.
String rupiah(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

// ── Policy detail + record payment ────────────────────────────────────────

class _PolicyPaymentScreen extends StatefulWidget {
  final AdminPolicyRepository repo;
  final AdminPolicyModel policy;

  const _PolicyPaymentScreen({required this.repo, required this.policy});

  @override
  State<_PolicyPaymentScreen> createState() => _PolicyPaymentScreenState();
}

class _PolicyPaymentScreenState extends State<_PolicyPaymentScreen> {
  late AdminPolicyModel _policy;
  Future<List<PremiPaymentModel>>? _future;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _policy = widget.policy;
    _future = widget.repo.getPayments(_policy.id);
  }

  void _reloadPayments() =>
      // Blok: arrow akan mengembalikan Future ke setState (assertion Flutter).
      setState(() {
        _future = widget.repo.getPayments(_policy.id);
      });

  Future<void> _recordPayment() async {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    DateTime paidDate = DateTime.now();

    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final formKey = GlobalKey<FormState>();
    // Dialog mengembalikan PAYLOAD, bukan sekadar true: nilai controller dibaca
    // selagi dialog masih hidup. Sebelumnya dibaca setelah dialog ditutup,
    // padahal controller-nya sudah/sedang dibuang bersama route — cacat yang
    // sama dengan sheet Edit Customer (layar merah saat menyimpan).
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      // Controller dibuang saat dialog benar-benar lepas dari tree (setelah animasi
      // keluar), bukan tepat setelah `await` — lihat dispose_callback.dart.
      builder: (ctx) => DisposeCallback(
        onDispose: () {
          amountC.dispose();
          noteC.dispose();
        },
        child: StatefulBuilder(
        builder: (ctx, setSt) {
          InputDecoration dec(String? hint, {String? label}) => InputDecoration(
            hintText: hint,
            labelText: label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          );
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            title: const Text(
              'Catat Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sisa premi: ${rupiah(_policy.remaining)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jumlah Pembayaran (IDR)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: amountC,
                      style: AppInput.fieldText,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsInputFormatter()],
                      decoration: dec('mis. 50.000.000'),
                      validator: (v) {
                        final n = double.tryParse(
                            (v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
                        if (n == null || n <= 0) {
                          return 'Jumlah harus angka > 0';
                        }
                        if (n > _policy.remaining + 0.0001) {
                          return 'Melebihi sisa premi (${rupiah(_policy.remaining)})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: paidDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setSt(() => paidDate = picked);
                      },
                      child: InputDecorator(
                        decoration: dec(null, label: 'Tanggal Bayar'),
                        child: Text(
                          iso(paidDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Catatan (opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: noteC,
                      style: AppInput.fieldText,
                      decoration: dec('mis. Cicilan ke-2'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(ctx).pop(<String, dynamic>{
                    'amount':
                        double.parse(amountC.text.replaceAll(RegExp(r'[^0-9]'), '')),
                    'paidDate': iso(paidDate),
                    'note': noteC.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusSm,
                  ),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await widget.repo.recordPayment(
        _policy.id,
        amount: result['amount'] as double,
        paidDate: result['paidDate'] as String,
        note: result['note'] as String,
      );
      if (!mounted) return;
      setState(() {
        _policy = updated;
        _dirty = true;
      });
      _reloadPayments();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updated.lunas
                ? 'Pembayaran tercatat. Premi LUNAS — komisi penuh dilepas.'
                : 'Pembayaran tercatat & komisi agen dilepas.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, fallback: 'Gagal mencatat pembayaran.')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _policy;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_dirty);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        appBar: const BackAppBar(title: 'Detail Premi Polis'),
        floatingActionButton: p.lunas
            ? null
            : FloatingActionButton.extended(
                onPressed: _recordPayment,
                backgroundColor: AppColors.primaryNavy,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Catat Pembayaran',
                  style: TextStyle(color: Colors.white),
                ),
              ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: AppColors.border),
                boxShadow: const [AppShadows.level1],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.policyNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.customerName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agen: ${p.agentName ?? '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 24),
                  _summaryRow('Total Premi', rupiah(p.premiGross)),
                  _summaryRow('Sudah Dibayar', rupiah(p.totalPaid)),
                  _summaryRow('Sisa', rupiah(p.remaining), highlight: !p.lunas),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: LinearProgressIndicator(
                      value: p.progress,
                      minHeight: 8,
                      backgroundColor: AppColors.grayBg,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        p.lunas
                            ? AppColors.successGreen
                            : AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  if (p.lunas) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.successGreen,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Premi lunas — komisi penuh sudah dilepas',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Riwayat Pembayaran',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<PremiPaymentModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final payments = snapshot.data ?? [];
                if (payments.isEmpty) {
                  return const EmptyStateView(
                    inCard: true,
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada pembayaran',
                  );
                }
                return Column(
                  children: payments.map(_buildPaymentCard).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight
                  ? AppColors.secondaryOrange
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PremiPaymentModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rupiah(p.amount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    p.paidDate ?? '-',
                    if (p.note != null && p.note!.isNotEmpty) p.note!,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (p.commissionAmount != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Komisi',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  rupiah(p.commissionAmount!),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
