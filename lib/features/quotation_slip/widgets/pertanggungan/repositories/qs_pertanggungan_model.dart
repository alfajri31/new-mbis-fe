class QsPertanggunganResponse {
  final String? id;
  final String? productCode;
  final PemegangPolisData? pemegangPolis;
  final TipePertanggunganData? tipePertanggungan;
  final PerhitunganPremiData? perhitunganPremi;
  final int? klasifikasiPeserta;
  final JangkaWaktuData? jangkaWaktu;
  final OrangDipertanggungkanData? orangDipertanggungkan;
  final QsStep2Data? step2;
  final QsStep3Data? step3;
  final QsPerhitunganBiayaData? perhitunganBiaya;

  QsPertanggunganResponse({
    this.id,
    this.productCode,
    this.pemegangPolis,
    this.tipePertanggungan,
    this.perhitunganPremi,
    this.klasifikasiPeserta,
    this.jangkaWaktu,
    this.orangDipertanggungkan,
    this.step2,
    this.step3,
    this.perhitunganBiaya,
  });

  factory QsPertanggunganResponse.fromJson(Map<String, dynamic> json) {
    return QsPertanggunganResponse(
      id: json['id']?.toString(),
      productCode: json['productCode']?.toString(),
      pemegangPolis: json['pemegangPolis'] is Map<String, dynamic>
          ? PemegangPolisData.fromJson(json['pemegangPolis'])
          : null,
      tipePertanggungan: json['tipePertanggungan'] is Map<String, dynamic>
          ? TipePertanggunganData.fromJson(json['tipePertanggungan'])
          : null,
      perhitunganPremi: json['perhitunganPremi'] is Map<String, dynamic>
          ? PerhitunganPremiData.fromJson(json['perhitunganPremi'])
          : null,
      klasifikasiPeserta: json['klasifikasiPeserta'] is Map
          ? int.tryParse(json['klasifikasiPeserta']['kelas']?.toString() ?? '')
          : (json['klasifikasiPeserta'] is num
              ? (json['klasifikasiPeserta'] as num).toInt()
              : int.tryParse(json['klasifikasiPeserta']?.toString() ?? '')),
      jangkaWaktu: json['jangkaWaktu'] is Map<String, dynamic>
          ? JangkaWaktuData.fromJson(json['jangkaWaktu'])
          : null,
      orangDipertanggungkan: json['orangDipertanggungkan'] is Map<String, dynamic>
          ? OrangDipertanggungkanData.fromJson(json['orangDipertanggungkan'])
          : null,
      step2: json['step2'] is Map<String, dynamic>
          ? QsStep2Data.fromJson(json['step2'])
          : null,
      step3: json['step3'] is Map<String, dynamic>
          ? QsStep3Data.fromJson(json['step3'])
          : null,
      perhitunganBiaya: json['perhitunganBiaya'] is Map<String, dynamic>
          ? QsPerhitunganBiayaData.fromJson(json['perhitunganBiaya'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productCode': productCode,
      'pemegangPolis': pemegangPolis?.toJson(),
      'tipePertanggungan': tipePertanggungan?.toJson(),
      'perhitunganPremi': perhitunganPremi?.toJson(),
      'klasifikasiPeserta': klasifikasiPeserta,
      'jangkaWaktu': jangkaWaktu?.toJson(),
      'orangDipertanggungkan': orangDipertanggungkan?.toJson(),
      'step2': step2?.toJson(),
      'step3': step3?.toJson(),
      'perhitunganBiaya': perhitunganBiaya?.toJson(),
    };
  }
}

class PemegangPolisData {
  final String? tertanggung;
  final String? alamat;
  final String? bidang;
  final String? email;
  final String? pic;
  final String? hpPic;

  PemegangPolisData({
    this.tertanggung,
    this.alamat,
    this.bidang,
    this.email,
    this.pic,
    this.hpPic,
  });

  factory PemegangPolisData.fromJson(Map<String, dynamic> json) {
    return PemegangPolisData(
      tertanggung: json['tertanggung']?.toString(),
      alamat: json['alamat']?.toString(),
      bidang: json['bidang']?.toString(),
      email: json['email']?.toString(),
      pic: json['pic']?.toString(),
      hpPic: json['hpPic']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'tertanggung': tertanggung,
    'alamat': alamat,
    'bidang': bidang,
    'email': email,
    'pic': pic,
    'hpPic': hpPic,
  };
}

class TipePertanggunganData {
  final String? qType;
  final int? jmlOrang;
  final String? aktivitas;

  TipePertanggunganData({
    this.qType,
    this.jmlOrang,
    this.aktivitas,
  });

  factory TipePertanggunganData.fromJson(Map<String, dynamic> json) {
    return TipePertanggunganData(
      qType: json['qType']?.toString(),
      jmlOrang: json['jmlOrang'] is num
          ? (json['jmlOrang'] as num).toInt()
          : int.tryParse(json['jmlOrang']?.toString() ?? ''),
      aktivitas: json['aktivitas']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'qType': qType,
    'jmlOrang': jmlOrang,
    'aktivitas': aktivitas,
  };
}

class PerhitunganPremiData {
  final String? calcType;

  PerhitunganPremiData({this.calcType});

  factory PerhitunganPremiData.fromJson(Map<String, dynamic> json) {
    return PerhitunganPremiData(
      calcType: json['calcType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'calcType': calcType,
  };
}

class JangkaWaktuData {
  final String? start;
  final String? end;

  JangkaWaktuData({this.start, this.end});

  factory JangkaWaktuData.fromJson(Map<String, dynamic> json) {
    return JangkaWaktuData(
      start: json['start']?.toString(),
      end: json['end']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
  };
}

class OrangDipertanggungkanData {
  final bool? samaDenganPP;
  final String? nama;
  final String? ktp;
  final String? lahir;
  final String? pekerjaan;

  OrangDipertanggungkanData({
    this.samaDenganPP,
    this.nama,
    this.ktp,
    this.lahir,
    this.pekerjaan,
  });

  factory OrangDipertanggungkanData.fromJson(Map<String, dynamic> json) {
    return OrangDipertanggungkanData(
      samaDenganPP: json['samaDenganPP'] == true,
      nama: json['nama']?.toString(),
      ktp: json['ktp']?.toString(),
      lahir: json['lahir']?.toString(),
      pekerjaan: json['pekerjaan']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'samaDenganPP': samaDenganPP,
    'nama': nama,
    'ktp': ktp,
    'lahir': lahir,
    'pekerjaan': pekerjaan,
  };
}

class QsStep2Data {
  final QsJaminanPokokData? jaminanPokok;
  final QsJaminanTambahanData? jaminanTambahan;
  final QsPerluasanData? perluasan;
  final double? discountPersen;
  final String? jenisPolis;
  final double? premiJaminanPokok;
  final double? premiJaminanTambahan;
  final double? tarifFlatPerHari;
  final dynamic psakdi;

  QsStep2Data({
    this.jaminanPokok,
    this.jaminanTambahan,
    this.perluasan,
    this.discountPersen,
    this.jenisPolis,
    this.premiJaminanPokok,
    this.premiJaminanTambahan,
    this.tarifFlatPerHari,
    this.psakdi,
  });

  factory QsStep2Data.fromJson(Map<String, dynamic> json) {
    return QsStep2Data(
      jaminanPokok: json['jaminanPokok'] is Map<String, dynamic>
          ? QsJaminanPokokData.fromJson(json['jaminanPokok'])
          : null,
      jaminanTambahan: json['jaminanTambahan'] is Map<String, dynamic>
          ? QsJaminanTambahanData.fromJson(json['jaminanTambahan'])
          : null,
      perluasan: json['perluasan'] is Map<String, dynamic>
          ? QsPerluasanData.fromJson(json['perluasan'])
          : null,
      discountPersen: (json['discountPersen'] as num?)?.toDouble() ??
          double.tryParse(json['discountPersen']?.toString() ?? ''),
      jenisPolis: json['jenisPolis']?.toString(),
      premiJaminanPokok: (json['premiJaminanPokok'] as num?)?.toDouble() ??
          double.tryParse(json['premiJaminanPokok']?.toString() ?? ''),
      premiJaminanTambahan: (json['premiJaminanTambahan'] as num?)?.toDouble() ??
          double.tryParse(json['premiJaminanTambahan']?.toString() ?? ''),
      tarifFlatPerHari: (json['tarifFlatPerHari'] as num?)?.toDouble() ??
          double.tryParse(json['tarifFlatPerHari']?.toString() ?? ''),
      psakdi: json['psakdi'] is Map<String, dynamic>
          ? QsPsakdiStep2Data.fromJson(json['psakdi'])
          : json['psakdi'],
    );
  }

  Map<String, dynamic> toJson() => {
    'jaminanPokok': jaminanPokok?.toJson(),
    'jaminanTambahan': jaminanTambahan?.toJson(),
    'perluasan': perluasan?.toJson(),
    'discountPersen': discountPersen,
    'jenisPolis': jenisPolis,
    'premiJaminanPokok': premiJaminanPokok,
    'premiJaminanTambahan': premiJaminanTambahan,
    'tarifFlatPerHari': tarifFlatPerHari,
    'psakdi': psakdi is QsPsakdiStep2Data
        ? (psakdi as QsPsakdiStep2Data).toJson()
        : psakdi,
  };
}

class QsJaminanPokokData {
  final double? uangPertanggunganMeninggalDunia;

  QsJaminanPokokData({this.uangPertanggunganMeninggalDunia});

  factory QsJaminanPokokData.fromJson(Map<String, dynamic> json) {
    return QsJaminanPokokData(
      uangPertanggunganMeninggalDunia:
          (json['uangPertanggunganMeninggalDunia'] as num?)?.toDouble() ??
              double.tryParse(
                  json['uangPertanggunganMeninggalDunia']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'uangPertanggunganMeninggalDunia': uangPertanggunganMeninggalDunia,
  };
}

class QsJaminanTambahanData {
  final bool? cacatTetap;
  final double? biayaPerawatanPengobatan;

  QsJaminanTambahanData({
    this.cacatTetap,
    this.biayaPerawatanPengobatan,
  });

  factory QsJaminanTambahanData.fromJson(Map<String, dynamic> json) {
    return QsJaminanTambahanData(
      cacatTetap: json['cacatTetap'] == true,
      biayaPerawatanPengobatan:
          (json['biayaPerawatanPengobatan'] as num?)?.toDouble() ??
              double.tryParse(
                  json['biayaPerawatanPengobatan']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'cacatTetap': cacatTetap,
    'biayaPerawatanPengobatan': biayaPerawatanPengobatan,
  };
}

class QsPerluasanData {
  final double? santunanAmbulansEvakuasi;
  final double? santunanPemakamanKremasi;
  final double? santunanKehilanganBarangPribadi;
  final double? santunanPengurusanDokumen;
  final double? santunanBiayaPendidikan;
  final double? santunanPemulanganJenazah;

  QsPerluasanData({
    this.santunanAmbulansEvakuasi,
    this.santunanPemakamanKremasi,
    this.santunanKehilanganBarangPribadi,
    this.santunanPengurusanDokumen,
    this.santunanBiayaPendidikan,
    this.santunanPemulanganJenazah,
  });

  factory QsPerluasanData.fromJson(Map<String, dynamic> json) {
    return QsPerluasanData(
      santunanAmbulansEvakuasi:
          (json['santunanAmbulansEvakuasi'] as num?)?.toDouble() ??
              double.tryParse(
                  json['santunanAmbulansEvakuasi']?.toString() ?? ''),
      santunanPemakamanKremasi:
          (json['santunanPemakamanKremasi'] as num?)?.toDouble() ??
              double.tryParse(
                  json['santunanPemakamanKremasi']?.toString() ?? ''),
      santunanKehilanganBarangPribadi:
          (json['santunanKehilanganBarangPribadi'] as num?)?.toDouble() ??
              double.tryParse(
                  json['santunanKehilanganBarangPribadi']?.toString() ?? ''),
      santunanPengurusanDokumen:
          (json['santunanPengurusanDokumen'] as num?)?.toDouble() ??
              double.tryParse(
                  json['santunanPengurusanDokumen']?.toString() ?? ''),
      santunanBiayaPendidikan:
          (json['santunanBiayaPendidikan'] as num?)?.toDouble() ??
              double.tryParse(
                  json['santunanBiayaPendidikan']?.toString() ?? ''),
      santunanPemulanganJenazah:
          (json['santunanPemulanganJenazah'] as num?)?.toDouble() ??
              double.tryParse(
                  json['santunanPemulanganJenazah']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'santunanAmbulansEvakuasi': santunanAmbulansEvakuasi,
    'santunanPemakamanKremasi': santunanPemakamanKremasi,
    'santunanKehilanganBarangPribadi': santunanKehilanganBarangPribadi,
    'santunanPengurusanDokumen': santunanPengurusanDokumen,
    'santunanBiayaPendidikan': santunanBiayaPendidikan,
    'santunanPemulanganJenazah': santunanPemulanganJenazah,
  };
}

class QsStep3Data {
  final QsPenerbitanData? penerbitan;
  final String? berlakuSampai;
  final List<QsTermsData>? terms;

  QsStep3Data({
    this.penerbitan,
    this.berlakuSampai,
    this.terms,
  });

  factory QsStep3Data.fromJson(Map<String, dynamic> json) {
    return QsStep3Data(
      penerbitan: json['penerbitan'] is Map<String, dynamic>
          ? QsPenerbitanData.fromJson(json['penerbitan'])
          : null,
      berlakuSampai: json['berlakuSampai']?.toString(),
      terms: json['terms'] is List
          ? (json['terms'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => QsTermsData.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'penerbitan': penerbitan?.toJson(),
    'berlakuSampai': berlakuSampai,
    'terms': terms?.map((e) => e.toJson()).toList(),
  };
}

class QsPenerbitanData {
  final String? kota;
  final String? tanggalTerbit;
  final String? cabang;
  final String? penandatangan;
  final String? jabatanPenandatangan;

  QsPenerbitanData({
    this.kota,
    this.tanggalTerbit,
    this.cabang,
    this.penandatangan,
    this.jabatanPenandatangan,
  });

  factory QsPenerbitanData.fromJson(Map<String, dynamic> json) {
    return QsPenerbitanData(
      kota: json['kota']?.toString(),
      tanggalTerbit: json['tanggalTerbit']?.toString(),
      cabang: json['cabang']?.toString(),
      penandatangan: json['penandatangan']?.toString(),
      jabatanPenandatangan: json['jabatanPenandatangan']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'kota': kota,
    'tanggalTerbit': tanggalTerbit,
    'cabang': cabang,
    'penandatangan': penandatangan,
    'jabatanPenandatangan': jabatanPenandatangan,
  };
}

class QsTermsData {
  final String? tipeTerms;
  final List<String>? descriptions;

  QsTermsData({
    this.tipeTerms,
    this.descriptions,
  });

  factory QsTermsData.fromJson(Map<String, dynamic> json) {
    return QsTermsData(
      tipeTerms: json['tipeTerms']?.toString(),
      descriptions: json['descriptions'] is List
          ? (json['descriptions'] as List)
              .map((e) => e.toString())
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'tipeTerms': tipeTerms,
    'descriptions': descriptions,
  };
}

class QsPerhitunganBiayaData {
  final double? premiJaminanPokok;
  final double? premiJaminanTambahan;
  final double? grossPremi;
  final double? nilaiDiscount;
  final double? nettPremi;
  final double? adminCost;
  final double? biayaAsuransi;
  final bool? requiresUwApproval;

  QsPerhitunganBiayaData({
    this.premiJaminanPokok,
    this.premiJaminanTambahan,
    this.grossPremi,
    this.nilaiDiscount,
    this.nettPremi,
    this.adminCost,
    this.biayaAsuransi,
    this.requiresUwApproval,
  });

  factory QsPerhitunganBiayaData.fromJson(Map<String, dynamic> json) {
    return QsPerhitunganBiayaData(
      premiJaminanPokok: (json['premiJaminanPokok'] as num?)?.toDouble() ??
          double.tryParse(json['premiJaminanPokok']?.toString() ?? ''),
      premiJaminanTambahan: (json['premiJaminanTambahan'] as num?)?.toDouble() ??
          double.tryParse(json['premiJaminanTambahan']?.toString() ?? ''),
      grossPremi: (json['grossPremi'] as num?)?.toDouble() ??
          double.tryParse(json['grossPremi']?.toString() ?? ''),
      nilaiDiscount: (json['nilaiDiscount'] as num?)?.toDouble() ??
          double.tryParse(json['nilaiDiscount']?.toString() ?? ''),
      nettPremi: (json['nettPremi'] as num?)?.toDouble() ??
          double.tryParse(json['nettPremi']?.toString() ?? ''),
      adminCost: (json['adminCost'] as num?)?.toDouble() ??
          double.tryParse(json['adminCost']?.toString() ?? ''),
      biayaAsuransi: (json['biayaAsuransi'] as num?)?.toDouble() ??
          double.tryParse(json['biayaAsuransi']?.toString() ?? ''),
      requiresUwApproval: json['requiresUwApproval'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'premiJaminanPokok': premiJaminanPokok,
    'premiJaminanTambahan': premiJaminanTambahan,
    'grossPremi': grossPremi,
    'nilaiDiscount': nilaiDiscount,
    'nettPremi': nettPremi,
    'adminCost': adminCost,
    'biayaAsuransi': biayaAsuransi,
    'requiresUwApproval': requiresUwApproval,
  };
}

class QsPsakdiStep2Data {
  final String? jenisRisiko;
  final double? uangPertanggunganMeninggalDunia;
  final double? uangPertanggunganBiayaPengobatan;
  final String? risikoDijamin;
  final double? rateUtama;
  final double? ratePengobatan;
  final double? premiUtama;
  final double? premiPengobatan;

  QsPsakdiStep2Data({
    this.jenisRisiko,
    this.uangPertanggunganMeninggalDunia,
    this.uangPertanggunganBiayaPengobatan,
    this.risikoDijamin,
    this.rateUtama,
    this.ratePengobatan,
    this.premiUtama,
    this.premiPengobatan,
  });

  factory QsPsakdiStep2Data.fromJson(Map<String, dynamic> json) {
    return QsPsakdiStep2Data(
      jenisRisiko: json['jenisRisiko']?.toString(),
      uangPertanggunganMeninggalDunia:
          (json['uangPertanggunganMeninggalDunia'] as num?)?.toDouble() ??
              double.tryParse(
                  json['uangPertanggunganMeninggalDunia']?.toString() ?? ''),
      uangPertanggunganBiayaPengobatan:
          (json['uangPertanggunganBiayaPengobatan'] as num?)?.toDouble() ??
              double.tryParse(
                  json['uangPertanggunganBiayaPengobatan']?.toString() ?? ''),
      risikoDijamin: json['risikoDijamin']?.toString(),
      rateUtama: (json['rateUtama'] as num?)?.toDouble() ??
          double.tryParse(json['rateUtama']?.toString() ?? ''),
      ratePengobatan: (json['ratePengobatan'] as num?)?.toDouble() ??
          double.tryParse(json['ratePengobatan']?.toString() ?? ''),
      premiUtama: (json['premiUtama'] as num?)?.toDouble() ??
          double.tryParse(json['premiUtama']?.toString() ?? ''),
      premiPengobatan: (json['premiPengobatan'] as num?)?.toDouble() ??
          double.tryParse(json['premiPengobatan']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'jenisRisiko': jenisRisiko,
    'uangPertanggunganMeninggalDunia': uangPertanggunganMeninggalDunia,
    'uangPertanggunganBiayaPengobatan': uangPertanggunganBiayaPengobatan,
    'risikoDijamin': risikoDijamin,
    if (rateUtama != null) 'rateUtama': rateUtama,
    if (ratePengobatan != null) 'ratePengobatan': ratePengobatan,
    if (premiUtama != null) 'premiUtama': premiUtama,
    if (premiPengobatan != null) 'premiPengobatan': premiPengobatan,
  };
}

/// Model response dari API POST /api/pipelines/{{pipelineId}}/quotation-slips/{{productCode}}
class QuotationSlipResponse {
  final String? id;
  final String? pipelineId;
  final String? productCode;
  final int? noUrut;
  final String? status;
  final int? rev;
  final double? totalPremi;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;
  final QsPertanggunganResponse? payload;
  final String? nomorQs;
  final String? uwReason;
  final String? fileKtp;
  final bool? deviation;

  QuotationSlipResponse({
    this.id,
    this.pipelineId,
    this.productCode,
    this.noUrut,
    this.status,
    this.rev,
    this.totalPremi,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.payload,
    this.nomorQs,
    this.uwReason,
    this.fileKtp,
    this.deviation,
  });

  factory QuotationSlipResponse.fromJson(Map<String, dynamic> json) {
    return QuotationSlipResponse(
      id: json['id']?.toString(),
      pipelineId: json['pipelineId']?.toString(),
      productCode: json['productCode']?.toString(),
      noUrut: (json['noUrut'] as num?)?.toInt() ??
          int.tryParse(json['noUrut']?.toString() ?? ''),
      status: json['status']?.toString(),
      rev: (json['rev'] as num?)?.toInt() ??
          int.tryParse(json['rev']?.toString() ?? ''),
      totalPremi: (json['totalPremi'] as num?)?.toDouble() ??
          double.tryParse(json['totalPremi']?.toString() ?? ''),
      createdBy: json['createdBy']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      payload: json['payload'] is Map<String, dynamic>
          ? QsPertanggunganResponse.fromJson(json['payload'])
          : null,
      nomorQs: json['nomorQs']?.toString(),
      uwReason: json['uwReason']?.toString(),
      fileKtp: json['fileKtp']?.toString(),
      deviation: json['deviation'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pipelineId': pipelineId,
    'productCode': productCode,
    'noUrut': noUrut,
    'status': status,
    'rev': rev,
    'totalPremi': totalPremi,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'payload': payload?.toJson(),
    'nomorQs': nomorQs,
    'uwReason': uwReason,
    'fileKtp': fileKtp,
    'deviation': deviation,
  };
}
