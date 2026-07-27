import '../../utils/format.dart';

/// Global KPIs shared by the BUMN and Broker screens (backend PartnerKpiResponse).
/// [total] is the whole master universe (all 515 BUMN / 150 broker); the rest
/// summarise the partner-linked pipelines nationally.
class PartnerKpi {
  final int total; // master entities in DB (515 BUMN / 150 broker)
  final int withPipeline; // entities with >= 1 linked pipeline
  final int everWon; // entities with >= 1 WON pipeline
  final double totalRealisasiPremi; // Σ realisasi_idr of WON pipelines
  final int p3;
  final int p2;
  final int p1;
  final int won;
  final int decline;

  const PartnerKpi({
    this.total = 0,
    this.withPipeline = 0,
    this.everWon = 0,
    this.totalRealisasiPremi = 0,
    this.p3 = 0,
    this.p2 = 0,
    this.p1 = 0,
    this.won = 0,
    this.decline = 0,
  });

  String get totalRealisasiPremiShort => AppFormat.currencyShort(totalRealisasiPremi);

  factory PartnerKpi.fromJson(Map<String, dynamic> json) => PartnerKpi(
        total: json['total'] ?? 0,
        withPipeline: json['withPipeline'] ?? 0,
        everWon: json['everWon'] ?? 0,
        totalRealisasiPremi: (json['totalRealisasiPremi'] ?? 0).toDouble(),
        p3: json['p3'] ?? 0,
        p2: json['p2'] ?? 0,
        p1: json['p1'] ?? 0,
        won: json['won'] ?? 0,
        decline: json['decline'] ?? 0,
      );
}
