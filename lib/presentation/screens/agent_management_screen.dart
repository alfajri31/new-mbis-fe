import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/auth/roles.dart';
import '../../src/network/api_client.dart';
import '../../src/agent/agent_repository.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/state_views.dart';
import 'ajukan_agen_screen.dart';

/// Human label for an [AgentStatus] code.
String agentStatusLabel(String status) {
  switch (status) {
    case 'DRAFT':
      return 'Draft';
    case 'WAITING_APPROVAL':
      return 'Menunggu Persetujuan';
    case 'WAITING_LICENSE':
      return 'Menunggu Lisensi';
    case 'WAITING_RM_DOCS':
      return 'Menunggu Dokumen';
    case 'WAITING_CIF':
      return 'Menunggu CIF';
    case 'ACTIVE':
      return 'Aktif';
    case 'REJECTED':
      return 'Ditolak';
    case 'INACTIVE':
      return 'Nonaktif';
    case 'EXPIRED':
      return 'Lisensi Habis';
    case 'WAITING_RENEWAL':
      return 'Menunggu Perpanjangan';
    default:
      return status;
  }
}

Color agentStatusColor(String status) {
  switch (status) {
    case 'ACTIVE':
      return AppColors.successGreen;
    case 'WAITING_APPROVAL':
    case 'WAITING_LICENSE':
    case 'WAITING_RM_DOCS':
    case 'WAITING_CIF':
    case 'WAITING_RENEWAL':
      return AppColors.secondaryOrange;
    case 'REJECTED':
    case 'EXPIRED':
      return AppColors.errorRed;
    default:
      return AppColors.grayStage;
  }
}

String agentTypeLabel(String type) => type == 'TPM' ? 'TPM' : 'Agen';

/// Human label for an agent onboarding document code (phase-1 registration &
/// phase-2 post-license). Falls back to the raw code for unknown types.
String agentDocLabel(String code) {
  switch (code) {
    // Phase 1 — pendaftaran
    case 'KTP':
      return 'Fotokopi KTP';
    case 'NPWP':
      return 'Fotokopi NPWP';
    case 'PIPELINE':
      return 'Dokumen Pipeline';
    case 'SURAT_PERNYATAAN':
      return 'Surat Pernyataan Bermeterai';
    case 'PENGALAMAN_KERJA':
      return 'Pengalaman Kerja';
    case 'MEMO_1':
      return 'Memo Pengajuan';
    case 'AAUI':
      return 'Copy AAUI';
    case 'SK_DOMISILI':
      return 'SK Domisili';
    case 'SURAT_PENGUNDURAN_DIRI':
      return 'Surat Pengunduran Diri';
    // Phase 2 — setelah lisensi
    case 'PAKTA_INTEGRITAS':
      return 'Pakta Integritas';
    case 'PKS':
      return 'Perjanjian Kerja Sama (PKS)';
    case 'SMAP':
      return 'SMAP (Sistem Manajemen Anti Penyuapan)';
    case 'MEMO_2':
      return 'Memo (Setelah Lisensi)';
    default:
      return code;
  }
}

/// S-150 — Manajemen Agen. Back-office worklist for the agent onboarding flow.
/// Tabs adapt to the caller's role: every allowed user sees "Semua"; a Branch
/// Manager also gets "Persetujuan" (pending); pengelola agen kantor pusat
/// (ADMIN atau Divisi Pengelolaan Agen) mendapat "Lisensi" & "Perpanjangan".
///
/// Dengan [mine] layar yang sama menjadi "Pengajuan Agen / TPM" milik RM: hanya
/// agen yang IA daftarkan, plus tombol mengajukan yang baru. Itu satu-satunya
/// bentuk layar ini yang boleh dilihat RM — mengurus agen yang sudah terdaftar
/// (lisensi, perpanjangan, koreksi data, CIF) adalah pekerjaan kantor pusat.
class AgentManagementScreen extends StatelessWidget {
  /// Mode "pengajuan saya" (RM), bukan konsol pengelolaan agen.
  final bool mine;
  const AgentManagementScreen({super.key, this.mine = false});

  @override
  Widget build(BuildContext context) {
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    final repo = AgentRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session));

    if (mine) return _pengajuanSaya(context, repo);

    // Konsol ini milik pimpinan kantor & kantor pusat. RM sampai di sini hanya
    // lewat tautan lama (/profil/manajemen-agen); pintunya di Profil sudah
    // diganti "Ajukan Agen / TPM" yang membuka mode [mine].
    final bolehKonsol = roles.any((r) => r == 'ADMIN' || r == 'BM' || r == 'RO' || r == 'KUP') ||
        roles.any(Roles.agentHqManagers.contains);
    if (!bolehKonsol) {
      return const Scaffold(
        backgroundColor: AppColors.bgScreen,
        appBar: BackAppBar(title: 'Manajemen Agen'),
        body: EmptyStateView(
          icon: Icons.lock_outline,
          title: 'Bukan untuk peran Anda',
          subtitle: 'Agen yang sudah terdaftar dikelola kantor pusat. Pengajuan '
              'agen/TPM Anda ada di Profil → "Ajukan Agen / TPM".',
        ),
      );
    }

    final tabs = <({String label, Future<List<AgentModel>> Function() loader, String emptyMsg})>[
      (
        label: 'Semua',
        loader: repo.getAgents,
        emptyMsg: 'Belum ada agen terdaftar di kantor Anda.',
      ),
    ];
    // DIV_AGEN ikut: sejak fase 1-2 dibuka untuknya, GET /api/agents/pending dan
    // /approve juga menerimanya, dan antreannya nasional (bukan per kantor). Tanpa
    // tab ini pengajuan yang dibuatnya sendiri lalu terlanjur diajukan tidak bisa
    // ia lihat maupun putuskan dari aplikasi.
    if (roles.any((r) => r == 'BM' || r == 'RO' || r == 'KUP') ||
        roles.any(Roles.agentHqManagers.contains)) {
      tabs.add((label: 'Pengajuan', loader: repo.getPending, emptyMsg: 'Tidak ada agen menunggu persetujuan.'));
    }
    // Lisensi & perpanjangan adalah pekerjaan kantor pusat, bukan cabang. Cermin
    // hasAnyRole('ADMIN','DIV_AGEN') di AgentController.
    if (roles.any(Roles.agentHqManagers.contains)) {
      tabs.add((label: 'Lisensi', loader: repo.getAwaitingLicense, emptyMsg: 'Tidak ada agen menunggu lisensi.'));
      tabs.add((label: 'Perpanjangan', loader: repo.getRenewals, emptyMsg: 'Tidak ada permohonan perpanjangan.'));
    }

    // Pintu "daftarkan agen" untuk kantor pusat. Pimpinan kantor tidak diberi FAB:
    // mereka memutuskan pengajuan, bukan membuatnya. RM sama sekali tidak sampai ke
    // konsol ini — pintunya "Ajukan Agen / TPM" di Profil (mode [mine]).
    //
    // Tanpa ini ADMIN & DIV_AGEN sama sekali tak punya jalan membuka form
    // pendaftaran: tombol di Profil disembunyikan `MbisApp.isSupervisorRole`, yang
    // mencakup ADMIN dan seluruh divisi kantor pusat.
    final fab = roles.any(Roles.agentHqManagers.contains)
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AjukanAgenScreen()),
            ),
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_alt_1, size: 20),
            label: const Text('Daftarkan Agen'),
          )
        : null;

    if (tabs.length == 1) {
      return Scaffold(
        backgroundColor: AppColors.bgScreen,
        appBar: const BackAppBar(title: 'Manajemen Agen'),
        floatingActionButton: fab,
        body: _AgentListTab(loader: tabs.first.loader, emptyMsg: tabs.first.emptyMsg),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceWhite,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: const Text('Manajemen Agen',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          bottom: TabBar(
            labelColor: AppColors.primaryNavy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryNavy,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [for (final t in tabs) Tab(text: t.label)],
          ),
        ),
        floatingActionButton: fab,
        body: TabBarView(
          children: [for (final t in tabs) _AgentListTab(loader: t.loader, emptyMsg: t.emptyMsg)],
        ),
      ),
    );
  }
}

/// Mode [AgentManagementScreen.mine] — pintu tunggal RM ke urusan agen.
///
/// Isinya HANYA pengajuan yang RM itu ajukan sendiri: mendaftarkan yang baru,
/// melanjutkan yang masih berjalan (unggah dokumen tahap-2, atur PKS, kirim ulang
/// yang ditolak), dan melihat mana yang sudah terdaftar. Tombol-tombol lanjutannya
/// ada di layar detail dan mati sendiri begitu agennya ACTIVE — server pun menolak,
/// jadi tidak ada layar yang menjanjikan aksi yang akan ditolak.
Widget _pengajuanSaya(BuildContext context, AgentRepository repo) {
  return Scaffold(
    backgroundColor: AppColors.bgScreen,
    appBar: const BackAppBar(title: 'Pengajuan Agen / TPM'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AjukanAgenScreen()),
      ),
      backgroundColor: AppColors.primaryNavy,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_alt_1, size: 20),
      label: const Text('Ajukan Baru'),
    ),
    body: _AgentListTab(
      loader: repo.getAgents,
      emptyMsg: 'Belum ada pengajuan. Tekan "Ajukan Baru" untuk mendaftarkan '
          'agen atau TPM.',
    ),
  );
}

class _AgentListTab extends StatefulWidget {
  final Future<List<AgentModel>> Function() loader;
  final String emptyMsg;
  const _AgentListTab({required this.loader, required this.emptyMsg});

  @override
  State<_AgentListTab> createState() => _AgentListTabState();
}

class _AgentListTabState extends State<_AgentListTab>
    with AutomaticKeepAliveClientMixin, RouteAware {
  late Future<List<AgentModel>> _future;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Kembali dari detail agen — muat ulang daftar. Memakai RouteObserver, BUKAN
  /// hasil `await context.push(...)`: layar detail bisa ditutup lewat tombol
  /// back sistem, gesture, atau `Navigator.pop` dari dialog hapus, dan tidak
  /// semua jalur itu menyelesaikan Future push. Akibatnya agen yang sudah
  /// dihapus masih tampil sebagai card sampai layar ditutup lalu dibuka lagi.
  @override
  void didPopNext() => _refresh();

  // Blok: arrow akan mengembalikan Future ke setState (assertion Flutter).
  void _refresh() => setState(() {
    _future = widget.loader();
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: TextField(
            style: AppInput.fieldText,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nama / CIF / NPWP…',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grayStage),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceWhite,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: FutureBuilder<List<AgentModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
                }
                if (snap.hasError) {
                  return ListView(children: [
                    const SizedBox(height: 120),
                    EmptyStateView(
                      icon: Icons.error_outline,
                      title: 'Gagal memuat',
                      subtitle: '${snap.error}'.replaceFirst('Exception: ', ''),
                    ),
                  ]);
                }
                final all = snap.data ?? const <AgentModel>[];
                final agents = _query.isEmpty
                    ? all
                    : all
                        .where((a) =>
                            a.name.toLowerCase().contains(_query) ||
                            a.cif.toLowerCase().contains(_query) ||
                            a.npwp.toLowerCase().contains(_query))
                        .toList();
                if (agents.isEmpty) {
                  return ListView(children: [
                    const SizedBox(height: 120),
                    EmptyStateView(
                      icon: Icons.groups_outlined,
                      title: _query.isEmpty ? 'Kosong' : 'Tidak ditemukan',
                      subtitle: _query.isEmpty ? widget.emptyMsg : 'Tidak ada agen cocok dengan "$_query".',
                    ),
                  ]);
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                      itemCount: agents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _AgentCard(agent: agents[i], onChanged: _refresh),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AgentModel agent;
  final VoidCallback onChanged;
  const _AgentCard({required this.agent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = agentStatusColor(agent.status);
    return Container(
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
          // Pemuatan ulang setelah kembali ditangani `didPopNext` di tab
          // (RouteObserver), jadi tidak bergantung pada Future push ini.
          onTap: () => context.push('/agent-detail/${agent.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: AppRadius.radiusSm),
                  child: Text(
                    agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${agentTypeLabel(agent.type)}'
                        '${agent.cif.isNotEmpty ? ' · CIF ${agent.cif}' : ''}'
                        '${agent.phone.isNotEmpty ? ' · ${agent.phone}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: agent.status, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        agentStatusLabel(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
