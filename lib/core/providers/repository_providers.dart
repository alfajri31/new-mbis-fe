import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/src/admin/account_repository.dart';
import 'package:mbis/src/admin/export_repository.dart';
import 'package:mbis/src/admin/policy_repository.dart';
import 'package:mbis/src/admin/realisasi_import_repository.dart';
import 'package:mbis/src/admin/target_import_repository.dart';
import 'package:mbis/src/agent/agent_repository.dart';
import 'package:mbis/src/announcement/announcement_repository.dart';
import 'package:mbis/src/assistant/ai_activity_admin_repository.dart';
import 'package:mbis/src/assistant/ai_usage_admin_repository.dart';
import 'package:mbis/src/assistant/assistant_repository.dart';
import 'package:mbis/src/broker/broker_repository.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';
import 'package:mbis/src/master_data/master_data_repository.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/premi/premi_estimate_repository.dart';
import 'package:mbis/src/reference/reference_repository.dart';
import 'package:mbis/src/region/region_repository.dart';
import 'package:mbis/src/referral/referral_repository.dart';
import 'package:mbis/src/rm_handover/rm_handover_repository.dart';
import 'package:mbis/src/rm_handover/rm_transfer_repository.dart';
import 'package:mbis/src/tender/tender_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

import 'app_providers.dart';

/// Provider untuk repository legacy (`lib/src/<domain>/`) yang sudah ada, di-wire
/// ke [apiClientProvider]. Dipakai oleh modul yang dimigrasi dari `setState` ke
/// Riverpod (mis. Notifier layar). Repository legacy dipakai ULANG apa adanya —
/// migrasi ini mengubah pengelolaan STATE, bukan menata ulang lapisan data.
///
/// Suffix `Repo` (bukan `Repository`) sengaja, agar tak bentruk nama dengan
/// `customerRepositoryProvider` di `features/customer` (exemplar terpisah).

final customerRepoProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(apiClient: ref.watch(apiClientProvider)),
);

final dashboardRepoProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(apiClient: ref.watch(apiClientProvider)),
);

final referenceRepoProvider = Provider<ReferenceRepository>(
  (ref) => ReferenceRepository(apiClient: ref.watch(apiClientProvider)),
);

final regionRepoProvider = Provider<RegionRepository>(
  (ref) => RegionRepository(apiClient: ref.watch(apiClientProvider)),
);

final pipelineRepoProvider = Provider<PipelineRepository>(
  (ref) => PipelineRepository(apiClient: ref.watch(apiClientProvider)),
);

final visitRepoProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(apiClient: ref.watch(apiClientProvider)),
);

final brokerRepoProvider = Provider<BrokerRepository>(
  (ref) => BrokerRepository(apiClient: ref.watch(apiClientProvider)),
);

final assistantRepoProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(apiClient: ref.watch(apiClientProvider)),
);

final announcementRepoProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(apiClient: ref.watch(apiClientProvider)),
);

final bumnRepoProvider = Provider<BumnRepository>(
  (ref) => BumnRepository(apiClient: ref.watch(apiClientProvider)),
);

final referralRepoProvider = Provider<ReferralRepository>(
  (ref) => ReferralRepository(apiClient: ref.watch(apiClientProvider)),
);

final tenderRepoProvider = Provider<TenderRepository>(
  (ref) => TenderRepository(apiClient: ref.watch(apiClientProvider)),
);

final premiEstimateRepoProvider = Provider<PremiEstimateRepository>(
  (ref) => PremiEstimateRepository(apiClient: ref.watch(apiClientProvider)),
);

// --- RM handover / transfer ---
final rmHandoverRepoProvider = Provider<RmHandoverRepository>(
  (ref) => RmHandoverRepository(apiClient: ref.watch(apiClientProvider)),
);

final rmTransferRepoProvider = Provider<RmTransferRepository>(
  (ref) => RmTransferRepository(apiClient: ref.watch(apiClientProvider)),
);

// --- Agen portal ---
final agentRepoProvider = Provider<AgentRepository>(
  (ref) => AgentRepository(apiClient: ref.watch(apiClientProvider)),
);

// --- Master data + admin ---
final masterDataRepoProvider = Provider<MasterDataRepository>(
  (ref) => MasterDataRepository(apiClient: ref.watch(apiClientProvider)),
);

final accountRepoProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(apiClient: ref.watch(apiClientProvider)),
);

final exportRepoProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(apiClient: ref.watch(apiClientProvider)),
);

final targetImportRepoProvider = Provider<TargetImportRepository>(
  (ref) => TargetImportRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Unggahan rekap realisasi RESMI dari pusat (ADMIN). Terpisah dari impor target
/// meski berkas asalnya sama: yang satu menulis target, yang satu realisasi.
final realisasiImportRepoProvider = Provider<RealisasiImportRepository>(
  (ref) => RealisasiImportRepository(apiClient: ref.watch(apiClientProvider)),
);

final adminPolicyRepoProvider = Provider<AdminPolicyRepository>(
  (ref) => AdminPolicyRepository(apiClient: ref.watch(apiClientProvider)),
);

// --- AI admin ---
final aiUsageAdminRepoProvider = Provider<AiUsageAdminRepository>(
  (ref) => AiUsageAdminRepository(apiClient: ref.watch(apiClientProvider)),
);

final aiActivityAdminRepoProvider = Provider<AiActivityAdminRepository>(
  (ref) => AiActivityAdminRepository(apiClient: ref.watch(apiClientProvider)),
);

final aiModelAdminRepoProvider = Provider<AiModelAdminRepository>(
  (ref) => AiModelAdminRepository(apiClient: ref.watch(apiClientProvider)),
);
