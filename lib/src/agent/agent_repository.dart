import 'dart:convert';
import '../network/api_client.dart';

/// The logged-in agent's identity + agency data (GET /api/agents/me).
class AgentSelfModel {
  final String cif;
  final String name;
  final String type;
  final String status;
  final String kanwil;
  final String cabang;
  final String pksNumber;
  final String pksPeriod;
  final String licenseEnd;
  final String email;
  final String phone;
  final String initials;

  AgentSelfModel({
    required this.cif,
    required this.name,
    required this.type,
    required this.status,
    required this.kanwil,
    required this.cabang,
    required this.pksNumber,
    required this.pksPeriod,
    required this.licenseEnd,
    required this.email,
    required this.phone,
    required this.initials,
  });

  factory AgentSelfModel.fromJson(Map<String, dynamic> json) {
    return AgentSelfModel(
      cif: json['cif'] ?? '-',
      name: json['name'] ?? '-',
      type: json['type'] ?? 'AGENT',
      status: json['status'] ?? '-',
      kanwil: json['kanwil'] ?? '-',
      cabang: json['cabang'] ?? '-',
      pksNumber: json['pksNumber'] ?? '-',
      pksPeriod: json['pksPeriod'] ?? '-',
      licenseEnd: json['licenseEnd']?.toString() ?? '',
      email: json['email'] ?? '-',
      phone: json['phone'] ?? '-',
      initials: json['initials'] ?? '?',
    );
  }
}

/// Agent dashboard performance figures (GET /api/agents/me/dashboard).
/// Monetary values are raw IDR; format with AppFormat.currencyShort.
class AgentDashboardModel {
  final double targetYtd;
  final double produksiPremiYtd;
  final double komisiSiapCair;
  final double komisiYtd;
  final double nilaiPipeline;
  final int pipelineAktif;
  final int successRatePercent;
  final int totalCustomers;

  AgentDashboardModel({
    required this.targetYtd,
    required this.produksiPremiYtd,
    required this.komisiSiapCair,
    required this.komisiYtd,
    required this.nilaiPipeline,
    required this.pipelineAktif,
    required this.successRatePercent,
    required this.totalCustomers,
  });

  factory AgentDashboardModel.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => (v ?? 0).toDouble();
    int i(dynamic v) => (v ?? 0) is int ? (v ?? 0) as int : (v ?? 0).toInt();
    return AgentDashboardModel(
      targetYtd: d(json['targetYtd']),
      produksiPremiYtd: d(json['produksiPremiYtd']),
      komisiSiapCair: d(json['komisiSiapCair']),
      komisiYtd: d(json['komisiYtd']),
      nilaiPipeline: d(json['nilaiPipeline']),
      pipelineAktif: i(json['pipelineAktif']),
      successRatePercent: i(json['successRatePercent']),
      totalCustomers: i(json['totalCustomers']),
    );
  }
}

/// A commission row for the agent's "Ajukan Komisi" screen.
class CommissionModel {
  final String id;
  final String policyNumber;
  final String customerName;
  final double amount;

  /// "" when ready to claim; "Diterima" | "Diproses" | "Dikirim" once submitted.
  final String submissionStatus;

  /// ISO date of the premi payment that released this tranche; null if unknown.
  final String? paidDate;

  CommissionModel({
    required this.id,
    required this.policyNumber,
    required this.customerName,
    required this.amount,
    required this.submissionStatus,
    this.paidDate,
  });

  bool get isSubmitted => submissionStatus.isNotEmpty;

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: json['id'] ?? '',
      policyNumber: json['policyNumber'] ?? '-',
      customerName: json['customerName'] ?? '-',
      amount: (json['amount'] ?? 0).toDouble(),
      submissionStatus: json['submissionStatus'] ?? '',
      paidDate: json['paidDate'],
    );
  }
}

/// A full agent record for the back-office workflow (GET /api/agents,
/// /api/agents/{id}, /pending, /awaiting-license). Mirrors AgentResponse.
class AgentModel {
  final String id;
  final String cif;
  final String name;
  final String type; // AGENT | TPM
  final String status; // DRAFT | WAITING_APPROVAL | WAITING_LICENSE | WAITING_RM_DOCS | WAITING_CIF | ACTIVE | REJECTED | INACTIVE | EXPIRED | WAITING_RENEWAL
  /// Kantor tempat agen terdaftar. Ikut kantor RM pengaju; untuk pengajuan dari
  /// kantor pusat (DIV_AGEN) dipilih eksplisit saat mendaftar.
  final String officeId;
  final String phone;
  final String email;
  final String npwp;
  /// Alamat bebas-teks di luar alamat KTP/domisili terstruktur.
  final String address;
  final String bankName;
  final String accountNumber;
  final String ktpNumber;
  final String birthDate;
  final String gender;
  final String licenseNumber;
  final String licenseStart;
  final String licenseEnd;
  // PKS yang di-set RM lewat "Atur PKS". Dulu tak pernah dikirim backend, jadi
  // nilai yang sudah disimpan tidak tampil di layar mana pun.
  final String pksNumber;
  final String pksStart;
  final String pksEnd;
  /// Rate komisi agen sesuai PKS (pecahan, mis. 0.10 = 10%); null = pakai fallback.
  final double? commissionRate;
  final String rejectionReason;
  final String createdAt;

  /// 'BRANCH' = disetujui pimpinan kantor; 'DIRECT' = jalur langsung kantor pusat
  /// tanpa persetujuan cabang; '' = agen dari sebelum jejak ini ada (V59).
  final String approvalPath;
  // Alamat KTP
  final String ktpAddress;
  final String ktpProvince;
  final String ktpCity;
  final String ktpDistrict;
  final String ktpSubdistrict;
  final String ktpRt;
  final String ktpRw;
  final String ktpPostalCode;
  // Alamat Domisili
  final String domicileAddress;
  final String domicileProvince;
  final String domicileCity;
  final String domicileDistrict;
  final String domicileSubdistrict;
  final String domicileRt;
  final String domicileRw;
  final String domicilePostalCode;

  AgentModel({
    required this.id,
    required this.cif,
    required this.name,
    required this.type,
    required this.status,
    this.officeId = '',
    required this.phone,
    required this.email,
    required this.npwp,
    this.address = '',
    required this.bankName,
    required this.accountNumber,
    required this.ktpNumber,
    required this.birthDate,
    required this.gender,
    required this.licenseNumber,
    required this.licenseStart,
    required this.licenseEnd,
    required this.pksNumber,
    required this.pksStart,
    required this.pksEnd,
    this.commissionRate,
    required this.rejectionReason,
    required this.createdAt,
    this.approvalPath = '',
    required this.ktpAddress,
    required this.ktpProvince,
    required this.ktpCity,
    required this.ktpDistrict,
    required this.ktpSubdistrict,
    required this.ktpRt,
    required this.ktpRw,
    this.ktpPostalCode = '',
    required this.domicileAddress,
    required this.domicileProvince,
    required this.domicileCity,
    required this.domicileDistrict,
    required this.domicileSubdistrict,
    required this.domicileRt,
    required this.domicileRw,
    this.domicilePostalCode = '',
  });

  factory AgentModel.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    return AgentModel(
      id: s(j['id']),
      cif: s(j['cif']),
      name: s(j['name']),
      type: j['type']?.toString() ?? 'AGENT',
      status: j['status']?.toString() ?? 'DRAFT',
      officeId: s(j['officeId']),
      phone: s(j['phone']),
      email: s(j['email']),
      npwp: s(j['npwp']),
      address: s(j['address']),
      bankName: s(j['bankName']),
      accountNumber: s(j['accountNumber']),
      ktpNumber: s(j['ktpNumber']),
      birthDate: s(j['birthDate']),
      gender: s(j['gender']),
      licenseNumber: s(j['licenseNumber']),
      licenseStart: s(j['licenseStart']),
      licenseEnd: s(j['licenseEnd']),
      pksNumber: s(j['pksNumber']),
      pksStart: s(j['pksStart']),
      pksEnd: s(j['pksEnd']),
      commissionRate: (j['commissionRate'] as num?)?.toDouble(),
      rejectionReason: s(j['rejectionReason']),
      createdAt: s(j['createdAt']),
      approvalPath: s(j['approvalPath']),
      ktpAddress: s(j['ktpAddress']),
      ktpProvince: s(j['ktpProvince']),
      ktpCity: s(j['ktpCity']),
      ktpDistrict: s(j['ktpDistrict']),
      ktpSubdistrict: s(j['ktpSubdistrict']),
      ktpRt: s(j['ktpRt']),
      ktpRw: s(j['ktpRw']),
      ktpPostalCode: s(j['ktpPostalCode']),
      domicileAddress: s(j['domicileAddress']),
      domicileProvince: s(j['domicileProvince']),
      domicileCity: s(j['domicileCity']),
      domicileDistrict: s(j['domicileDistrict']),
      domicileSubdistrict: s(j['domicileSubdistrict']),
      domicileRt: s(j['domicileRt']),
      domicileRw: s(j['domicileRw']),
      domicilePostalCode: s(j['domicilePostalCode']),
    );
  }
}

/// An uploaded agent document (Pakta Integritas / PKS).
/// Grup rate komisi PKS (LOB / Asuransi Mikro). `code` = lob_code / ASURANSI_MIKRO.
class CommissionGroupModel {
  final String code;
  final String name;
  final String cobName;

  CommissionGroupModel({required this.code, required this.name, required this.cobName});

  factory CommissionGroupModel.fromJson(Map<String, dynamic> j) => CommissionGroupModel(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        cobName: j['cobName']?.toString() ?? '',
      );
}

class AgentDocumentModel {
  final String id;
  final String docType;
  final String fileName;
  final String fileUrl; // relative path served by /api/files/**
  final String status; // PENDING | APPROVED | REJECTED
  final String? rejectionReason;

  AgentDocumentModel({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.fileUrl,
    this.status = 'PENDING',
    this.rejectionReason,
  });

  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isPending => status == 'PENDING';

  factory AgentDocumentModel.fromJson(Map<String, dynamic> j) => AgentDocumentModel(
        id: j['id']?.toString() ?? '',
        docType: j['docType']?.toString() ?? '',
        fileName: j['fileName']?.toString() ?? '',
        fileUrl: j['fileUrl']?.toString() ?? '',
        status: j['status']?.toString() ?? 'PENDING',
        rejectionReason: j['rejectionReason']?.toString(),
      );
}

/// Satu kantor untuk pemilih "Kantor Agen" (GET /api/offices).
class OfficeOption {
  final String id;
  final String name;
  final String type; // REGIONAL | BRANCH | HEAD_OFFICE

  OfficeOption({required this.id, required this.name, required this.type});

  factory OfficeOption.fromJson(Map<String, dynamic> j) => OfficeOption(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
      );
}

/// Satu baris riwayat koreksi profil agen (GET /api/agents/{id}/profile-changes).
///
/// [changedFields] berisi NAMA field yang berubah, dipisah "; " — bukan nilai
/// lama/barunya. Nilainya tidak disimpan server karena PII (NIK, NPWP, no.
/// rekening), jadi layar riwayat hanya bisa menjawab "siapa mengubah apa dan
/// kenapa", bukan "dari nilai berapa ke berapa".
class AgentProfileChangeModel {
  final String id;
  final String changedBy;
  final String changedByName;
  final String changedAt;
  final String reason;
  final String changedFields;

  AgentProfileChangeModel({
    required this.id,
    required this.changedBy,
    required this.changedByName,
    required this.changedAt,
    required this.reason,
    required this.changedFields,
  });

  /// Field yang berubah sebagai daftar, untuk dirender jadi chip.
  List<String> get fields => changedFields
      .split(';')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  factory AgentProfileChangeModel.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    return AgentProfileChangeModel(
      id: s(j['id']),
      changedBy: s(j['changedBy']),
      // Akun pengubah bisa sudah dihapus — jatuh ke id supaya barisnya tetap bermakna.
      changedByName: (j['changedByName'] ?? j['changedBy'] ?? '-').toString(),
      changedAt: s(j['changedAt']),
      reason: s(j['reason']),
      changedFields: s(j['changedFields']),
    );
  }
}

/// Credentials returned when admin issues a CIF + login account.
class AgentCredentialModel {
  final String agentId;
  final String cif;
  final String loginNip;
  final String tempPassword;
  final String status;

  AgentCredentialModel({
    required this.agentId,
    required this.cif,
    required this.loginNip,
    required this.tempPassword,
    required this.status,
  });

  factory AgentCredentialModel.fromJson(Map<String, dynamic> j) => AgentCredentialModel(
        agentId: j['agentId']?.toString() ?? '',
        cif: j['cif']?.toString() ?? '',
        loginNip: j['loginNip']?.toString() ?? '',
        tempPassword: j['tempPassword']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
      );
}

/// A downloadable onboarding template (blank form). [available] is false until
/// an admin has uploaded the file.
class AgentTemplateItem {
  final String code;
  final String name;
  final bool available;
  final String fileName;
  final int? sortOrder;

  AgentTemplateItem({
    required this.code,
    required this.name,
    required this.available,
    required this.fileName,
    this.sortOrder,
  });

  factory AgentTemplateItem.fromJson(Map<String, dynamic> j) => AgentTemplateItem(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        available: (j['available'] ?? false) as bool,
        fileName: j['fileName']?.toString() ?? '',
        sortOrder: (j['sortOrder'] as num?)?.toInt(),
      );
}

/// API access for the agent portal and RM agent registration.
class AgentRepository {
  final ApiClient apiClient;

  AgentRepository({required this.apiClient});

  Future<AgentSelfModel> getMyProfile() async {
    final res = await apiClient.get('/api/agents/me');
    if (res.statusCode == 200) {
      return AgentSelfModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal memuat profil agen');
  }

  /// Agent uploads a renewal document (SURAT_PERNYATAAN or PIPELINE).
  Future<void> uploadRenewalDocument({
    required String docType,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final res = await apiClient.postMultipart(
      '/api/agents/me/renewal/documents',
      fields: {'docType': docType},
      fileField: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
    );
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal mengunggah dokumen'));
    }
  }

  /// Agent submits a license renewal request (documents must be uploaded first).
  Future<void> requestRenewal() async {
    final res = await apiClient.post('/api/agents/me/renewal');
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal mengajukan perpanjangan'));
    }
  }

  Future<AgentDashboardModel> getMyDashboard() async {
    final res = await apiClient.get('/api/agents/me/dashboard');
    if (res.statusCode == 200) {
      return AgentDashboardModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal memuat dashboard agen');
  }

  Future<List<CommissionModel>> getMyCommissions() async {
    final res = await apiClient.get('/api/agents/me/commissions');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => CommissionModel.fromJson(j)).toList();
    }
    throw Exception('Gagal memuat komisi');
  }

  Future<CommissionModel> submitCommission(String id) async {
    final res = await apiClient.post('/api/agents/me/commissions/$id/submit');
    if (res.statusCode == 200) {
      return CommissionModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal mengajukan komisi'));
  }

  /// RM registers a new Agent/TPM (POST /api/agents). [type] is 'AGENT' or 'TPM'.
  ///
  /// [officeId] hanya dipakai bila pengaju TIDAK duduk di sebuah kantor — yaitu
  /// pengelola agen kantor pusat (DIV_AGEN), yang harus menyebut kantor agennya.
  /// Untuk RM server mengabaikannya: kantor agen selalu mengikuti kantor pengaju.
  Future<AgentModel> createAgent({
    required String name,
    required String type,
    required String phone,
    required String email,
    String? officeId,
    String? npwp,
    String? bankName,
    String? accountNumber,
    String? ktpNumber,
    String? birthDate, // ISO yyyy-MM-dd
    String? gender,
    // Alamat KTP
    String? ktpAddress,
    String? ktpProvince,
    String? ktpCity,
    String? ktpDistrict,
    String? ktpSubdistrict,
    String? ktpRt,
    String? ktpRw,
    String? ktpPostalCode,
    // Alamat Domisili
    String? domicileAddress,
    String? domicileProvince,
    String? domicileCity,
    String? domicileDistrict,
    String? domicileSubdistrict,
    String? domicileRt,
    String? domicileRw,
    String? domicilePostalCode,
  }) async {
    final res = await apiClient.post('/api/agents', body: {
      'name': name,
      'type': type,
      'phone': phone,
      'email': email,
      'officeId': ?officeId,
      'npwp': npwp,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ktpNumber': ktpNumber,
      'birthDate': birthDate,
      'gender': gender,
      'ktpAddress': ktpAddress,
      'ktpProvince': ktpProvince,
      'ktpCity': ktpCity,
      'ktpDistrict': ktpDistrict,
      'ktpSubdistrict': ktpSubdistrict,
      'ktpRt': ktpRt,
      'ktpRw': ktpRw,
      'ktpPostalCode': ktpPostalCode,
      'domicileAddress': domicileAddress,
      'domicileProvince': domicileProvince,
      'domicileCity': domicileCity,
      'domicileDistrict': domicileDistrict,
      'domicileSubdistrict': domicileSubdistrict,
      'domicileRt': domicileRt,
      'domicileRw': domicileRw,
      'domicilePostalCode': domicilePostalCode,
    });
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AgentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal mengajukan agen'));
  }

  /// RM edits a DRAFT/REJECTED agent (PUT /api/agents/{id}). Body mirrors create;
  /// pass the full current values so unspecified fields are not blanked.
  Future<AgentModel> updateAgent(
    String id, {
    required String name,
    required String type,
    required String phone,
    required String email,
    String? npwp,
    String? bankName,
    String? accountNumber,
    String? ktpNumber,
    String? birthDate,
    String? gender,
    String? ktpAddress,
    String? ktpProvince,
    String? ktpCity,
    String? ktpDistrict,
    String? ktpSubdistrict,
    String? ktpRt,
    String? ktpRw,
    String? ktpPostalCode,
    String? domicileAddress,
    String? domicileProvince,
    String? domicileCity,
    String? domicileDistrict,
    String? domicileSubdistrict,
    String? domicileRt,
    String? domicileRw,
    String? domicilePostalCode,
  }) async {
    final res = await apiClient.put('/api/agents/$id', body: {
      'name': name,
      'type': type,
      'phone': phone,
      'email': email,
      'npwp': npwp,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ktpNumber': ktpNumber,
      'birthDate': birthDate,
      'gender': gender,
      'ktpAddress': ktpAddress,
      'ktpProvince': ktpProvince,
      'ktpCity': ktpCity,
      'ktpDistrict': ktpDistrict,
      'ktpSubdistrict': ktpSubdistrict,
      'ktpRt': ktpRt,
      'ktpRw': ktpRw,
      'ktpPostalCode': ktpPostalCode,
      'domicileAddress': domicileAddress,
      'domicileProvince': domicileProvince,
      'domicileCity': domicileCity,
      'domicileDistrict': domicileDistrict,
      'domicileSubdistrict': domicileSubdistrict,
      'domicileRt': domicileRt,
      'domicileRw': domicileRw,
      'domicilePostalCode': domicilePostalCode,
    });
    if (res.statusCode == 200) {
      return AgentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal menyimpan perubahan agen'));
  }

  /// Seluruh kantor (KW + KC) untuk pemilih "Kantor Agen".
  ///
  /// Sengaja TIDAK disaring ke BRANCH saja seperti dropdown referral: agen boleh
  /// bernaung di kantor wilayah, bukan hanya cabang.
  Future<List<OfficeOption>> offices() async {
    final res = await apiClient.get('/api/offices');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list
          .map((j) => OfficeOption.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar kantor'));
  }

  // ── Koreksi profil oleh pengelola agen kantor pusat ───────────────────────

  /// Mengoreksi data agen pada status APA PUN, termasuk ACTIVE
  /// (PUT /api/agents/{id}/profile — ADMIN &amp; DIV_AGEN).
  ///
  /// Berbeda dari [updateAgent] yang menuntut payload penuh: di sini field yang
  /// `null` TIDAK dikirim sama sekali, dan server memaknainya "jangan diubah".
  /// Kirim hanya yang benar-benar dikoreksi — payload penuh berisiko menghapus
  /// data yang kebetulan tidak dimuat layar. String kosong berarti "kosongkan".
  ///
  /// [reason] wajib dan tersimpan di riwayat ([getProfileChanges]).
  Future<AgentModel> updateAgentProfile(
    String id, {
    required String reason,
    String? name,
    String? phone,
    String? email,
    String? npwp,
    String? address,
    String? bankName,
    String? accountNumber,
    String? ktpNumber,
    String? birthDate,
    String? gender,
    String? ktpAddress,
    String? ktpProvince,
    String? ktpCity,
    String? ktpDistrict,
    String? ktpSubdistrict,
    String? ktpRt,
    String? ktpRw,
    String? ktpPostalCode,
    String? domicileAddress,
    String? domicileProvince,
    String? domicileCity,
    String? domicileDistrict,
    String? domicileSubdistrict,
    String? domicileRt,
    String? domicileRw,
    String? domicilePostalCode,
  }) async {
    final res = await apiClient.put('/api/agents/$id/profile', body: {
      'reason': reason,
      'name': ?name,
      'phone': ?phone,
      'email': ?email,
      'npwp': ?npwp,
      'address': ?address,
      'bankName': ?bankName,
      'accountNumber': ?accountNumber,
      'ktpNumber': ?ktpNumber,
      'birthDate': ?birthDate,
      'gender': ?gender,
      'ktpAddress': ?ktpAddress,
      'ktpProvince': ?ktpProvince,
      'ktpCity': ?ktpCity,
      'ktpDistrict': ?ktpDistrict,
      'ktpSubdistrict': ?ktpSubdistrict,
      'ktpRt': ?ktpRt,
      'ktpRw': ?ktpRw,
      'ktpPostalCode': ?ktpPostalCode,
      'domicileAddress': ?domicileAddress,
      'domicileProvince': ?domicileProvince,
      'domicileCity': ?domicileCity,
      'domicileDistrict': ?domicileDistrict,
      'domicileSubdistrict': ?domicileSubdistrict,
      'domicileRt': ?domicileRt,
      'domicileRw': ?domicileRw,
      'domicilePostalCode': ?domicilePostalCode,
    });
    if (res.statusCode == 200) {
      return AgentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal menyimpan koreksi data agen'));
  }

  /// Riwayat koreksi profil agen, terbaru dulu (ADMIN &amp; DIV_AGEN).
  Future<List<AgentProfileChangeModel>> getProfileChanges(String id) async {
    final res = await apiClient.get('/api/agents/$id/profile-changes');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list
          .map((j) => AgentProfileChangeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat riwayat koreksi'));
  }

  // ── Back-office workflow (RM / BM / ADMIN) ────────────────────────────────

  /// Agents visible to the caller (RM: own links; supervisor: office subtree; admin: all).
  Future<List<AgentModel>> getAgents() => _agentList('/api/agents');

  /// Agents in the BM's office waiting for approval.
  Future<List<AgentModel>> getPending() => _agentList('/api/agents/pending');

  /// Agents waiting for an admin to enter a license number.
  Future<List<AgentModel>> getAwaitingLicense() => _agentList('/api/agents/awaiting-license');

  /// Agents awaiting a renewal approval (admin).
  Future<List<AgentModel>> getRenewals() => _agentList('/api/agents/renewals');

  Future<List<AgentModel>> _agentList(String path) async {
    final res = await apiClient.get(path);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => AgentModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar agen'));
  }

  Future<AgentModel> getAgent(String id) async {
    final res = await apiClient.get('/api/agents/$id');
    if (res.statusCode == 200) {
      return AgentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal memuat detail agen'));
  }

  /// RM submits a DRAFT/REJECTED agent for supervisor approval (RO/BM/KUP).
  Future<AgentModel> submitForApproval(String id) =>
      _agentAction('/api/agents/$id/submit', 'Gagal mengajukan agen');

  /// RM deletes a pengajuan while it has not yet been approved.
  Future<void> deleteAgent(String id) async {
    final res = await apiClient.delete('/api/agents/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus pengajuan'));
    }
  }

  /// RM submits the phase-2 documents to hand off to admin for CIF issuance.
  Future<AgentModel> submitDocuments(String id) =>
      _agentAction('/api/agents/$id/submit-documents', 'Gagal mengirim dokumen');

  /// BM approves an agent awaiting approval.
  Future<AgentModel> approve(String id) =>
      _agentAction('/api/agents/$id/approve', 'Gagal menyetujui agen');

  /// Kantor pusat (ADMIN/DIV_AGEN) meloloskan pengajuan DRAFT/REJECTED tanpa
  /// persetujuan cabang — dipakai terutama saat memindahkan data agen lama.
  ///
  /// Field wajib & dokumen registrasi wajib TETAP diperiksa server; hanya memo
  /// yang dikecualikan, karena untuk agen lama usulan internalnya tidak pernah ada.
  Future<AgentModel> approveDirect(String id) =>
      _agentAction('/api/agents/$id/direct-approve',
          'Gagal memasukkan agen secara langsung');

  /// BM rejects an agent with an optional reason.
  Future<AgentModel> reject(String id, {String? reason}) =>
      _agentAction('/api/agents/$id/reject', 'Gagal menolak agen',
          body: {'reason': reason});

  /// Admin sets the license number (AGENT → ACTIVE).
  Future<AgentModel> setLicense(String id, String licenseNumber,
          {String? licenseStart, String? licenseEnd}) =>
      _agentAction('/api/agents/$id/license', 'Gagal menyimpan lisensi',
          body: {
            'licenseNumber': licenseNumber,
            'licenseStart': licenseStart,
            'licenseEnd': licenseEnd,
          });

  /// Admin approves a renewal with a new license number + period (→ ACTIVE).
  Future<AgentModel> approveRenewal(String id, String licenseNumber,
          {String? licenseStart, String? licenseEnd}) =>
      _agentAction('/api/agents/$id/renewal/approve', 'Gagal menyetujui perpanjangan',
          body: {
            'licenseNumber': licenseNumber,
            'licenseStart': licenseStart,
            'licenseEnd': licenseEnd,
          });

  Future<AgentModel> _agentAction(String path, String fallback, {Object? body}) async {
    final res = await apiClient.post(path, body: body);
    if (res.statusCode == 200) {
      return AgentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, fallback));
  }

  /// RM sets the PKS (cooperation agreement) number + period + commission rate.
  /// Dates are ISO yyyy-MM-dd. [commissionRate] is a fraction (0.10 = 10%); null
  /// leaves the existing rate unchanged.
  Future<AgentModel> setPks(String id,
      {required String pksNumber,
      String? pksStart,
      String? pksEnd,
      double? commissionRate,
      List<Map<String, dynamic>>? groupRates}) async {
    final res = await apiClient.put('/api/agents/$id/pks', body: {
      'pksNumber': pksNumber,
      'pksStart': pksStart,
      'pksEnd': pksEnd,
      'commissionRate': ?commissionRate,
      'groupRates': ?groupRates,
    });
    if (res.statusCode == 200) {
      return AgentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal menyimpan PKS'));
  }

  /// Daftar grup rate komisi (LOB + Mikro) untuk form PKS.
  Future<List<CommissionGroupModel>> getCommissionGroups() async {
    final res = await apiClient.get('/api/agents/commission-groups');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list
          .map((j) => CommissionGroupModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat grup komisi'));
  }

  /// Rate per-grup yang sudah tersimpan → map groupCode → rate (pecahan).
  Future<Map<String, double>> getCommissionRates(String id) async {
    final res = await apiClient.get('/api/agents/$id/commission-rates');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return {
        for (final j in list)
          (j['groupCode']?.toString() ?? ''): ((j['rate'] ?? 0) as num).toDouble(),
      };
    }
    throw Exception(_message(res.body, 'Gagal memuat rate komisi'));
  }

  /// Admin issues the CIF + creates the agent's login account.
  Future<AgentCredentialModel> issueCif(String id) async {
    final res = await apiClient.post('/api/agents/$id/issue-cif');
    if (res.statusCode == 200) {
      return AgentCredentialModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal menerbitkan CIF'));
  }

  Future<List<AgentDocumentModel>> getDocuments(String id) async {
    final res = await apiClient.get('/api/agents/$id/documents');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => AgentDocumentModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat dokumen'));
  }

  /// RM uploads a document (e.g. PAKTA_INTEGRITAS, PKS). [fileBytes] from a picker.
  Future<AgentDocumentModel> uploadDocument(
    String id, {
    required String docType,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final res = await apiClient.postMultipart(
      '/api/agents/$id/documents',
      fields: {'docType': docType},
      fileField: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
    );
    if (res.statusCode == 200) {
      return AgentDocumentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal mengunggah dokumen'));
  }

  /// Admin menyetujui sebuah dokumen agen.
  Future<AgentDocumentModel> approveDocument(String id, String docType) async {
    final res = await apiClient.post('/api/agents/$id/documents/$docType/approve');
    if (res.statusCode == 200) {
      return AgentDocumentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal menyetujui dokumen'));
  }

  /// Admin menolak sebuah dokumen agen dengan alasan (dikembalikan ke RM).
  Future<AgentDocumentModel> rejectDocument(String id, String docType, String reason) async {
    final res = await apiClient.post('/api/agents/$id/documents/$docType/reject',
        body: {'reason': reason});
    if (res.statusCode == 200) {
      return AgentDocumentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal menolak dokumen'));
  }

  /// Lists the onboarding document templates (any authenticated user).
  Future<List<AgentTemplateItem>> getAgentTemplates() async {
    final res = await apiClient.get('/api/agent-templates');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => AgentTemplateItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat template'));
  }

  /// Downloads a template file; returns its bytes + filename + content type.
  Future<({List<int> bytes, String fileName, String contentType})> downloadTemplate(String code) async {
    final res = await apiClient.get('/api/agent-templates/$code/download');
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? code,
        contentType: res.headers['content-type'] ?? 'application/octet-stream',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengunduh template'));
  }

  /// Mengunduh isi sebuah berkas yang tersimpan (mis. dokumen pengajuan agen)
  /// berdasar [fileUrl] relatif dari server (mulai dengan `/api/files/…`).
  /// Dipanggil dengan token auth via [apiClient], jadi reviewer (BM/RO/dll) bisa
  /// membuka berkas yang diunggah RM. [fallbackName] dipakai bila header tak
  /// menyertakan nama berkas.
  Future<({List<int> bytes, String fileName, String contentType})> downloadFile(
      String fileUrl, {String fallbackName = 'dokumen'}) async {
    final res = await apiClient.get(fileUrl);
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? fallbackName,
        contentType: res.headers['content-type'] ?? 'application/octet-stream',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengunduh berkas'));
  }

  /// Admin uploads/replaces a template file (PUT /api/agent-templates/{code}).
  Future<void> uploadTemplate(String code, {required List<int> fileBytes, required String fileName}) async {
    final res = await apiClient.putMultipart(
      '/api/agent-templates/$code',
      fileField: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
    );
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal mengunggah template'));
    }
  }

  /// Membuat jenis template baru (ADMIN). [code] boleh dikosongkan — server
  /// menurunkannya dari [name], mis. "Pakta Integritas" -> "PAKTA_INTEGRITAS".
  Future<AgentTemplateItem> createTemplate({
    required String name,
    String? code,
    int? sortOrder,
  }) async {
    final res = await apiClient.post('/api/agent-templates', body: {
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
      'sortOrder': ?sortOrder,
    });
    if (res.statusCode == 200) {
      return AgentTemplateItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal membuat template'));
  }

  /// Mengubah nama/urutan template (ADMIN). Kode tidak bisa diubah.
  Future<AgentTemplateItem> updateTemplate(
    String code, {
    required String name,
    int? sortOrder,
  }) async {
    final res = await apiClient.put('/api/agent-templates/$code/meta', body: {
      'name': name,
      'sortOrder': ?sortOrder,
    });
    if (res.statusCode == 200) {
      return AgentTemplateItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal menyimpan template'));
  }

  /// Menghapus template beserta berkasnya (ADMIN).
  Future<void> deleteTemplate(String code) async {
    final res = await apiClient.delete('/api/agent-templates/$code');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus template'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}
