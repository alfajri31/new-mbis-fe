import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../master_data/master_data_repository.dart';

/// Domain model + loader untuk Product Knowledge.
/// Sumber tunggal: backend DB via `/api/product-categories` + `/api/products`
/// (dikelola admin). Di-cache ke SharedPreferences untuk offline; asset
/// `assets/product_knowledge.json` hanya fallback terakhir. Lihat
/// [ProductKnowledgeRepository.load].

class PkCategory {
  final String id;
  final String name;
  final String icon; // nama ikon (lucide-style) — dipetakan ke IconData di UI
  final Color color;

  const PkCategory({required this.id, required this.name, required this.icon, required this.color});

  factory PkCategory.fromJson(Map<String, dynamic> j) => PkCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: (j['icon'] as String?) ?? 'shapes',
        color: _hexColor(j['colorHex'] as String?) ?? const Color(0xFF0D2C54),
      );
}

class PkProduct {
  final String id;
  final String slug;
  final String name;
  final String categoryId;
  final bool active;
  final Map<String, String> quickFacts;
  final Map<String, dynamic> rawSections; // String (prosa) atau List<String> (array)
  final String? skemaUrl;

  PkProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.categoryId,
    required this.active,
    required this.quickFacts,
    required this.rawSections,
    required this.skemaUrl,
  });

  /// Poin inti untuk strip utama: premi · masa · nilai (dari quickFacts).
  Map<String, String> cleanQuickFacts() {
    return {
      if (quickFacts['premi'] != null) 'premi': quickFacts['premi']!,
      if (quickFacts['masaPertanggungan'] != null) 'masa': quickFacts['masaPertanggungan']!,
      if (quickFacts['nilaiPertanggungan'] != null) 'nilai': quickFacts['nilaiPertanggungan']!,
    };
  }

  /// Kartu "jenis": List&lt;{title, detail}&gt; bila section 'jenis' berupa array objek.
  List<({String title, String detail})> jenisCards() {
    final v = rawSections['jenis'];
    if (v is List) {
      return v.whereType<Map>().map((m) => (
            title: (m['title'] ?? '').toString(),
            detail: (m['detail'] ?? '').toString(),
          )).toList();
    }
    return const [];
  }

  /// Section prosa (markdown ringan). Null jika tak ada / bukan teks.
  String? sectionText(String key) {
    final v = rawSections[key];
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  /// Section berupa daftar (pengecualian/persyaratan/tataCara/...). Kosong jika tak ada.
  List<String> sectionList(String key) {
    final v = rawSections[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  bool hasSection(String key) => rawSections.containsKey(key) && (sectionText(key) != null || sectionList(key).isNotEmpty);

  factory PkProduct.fromJson(Map<String, dynamic> j) {
    return PkProduct(
      id: j['id'] as String,
      slug: (j['slug'] as String?) ?? '',
      name: j['name'] as String,
      categoryId: (j['categoryId'] as String?) ?? 'lainnya',
      active: (j['status'] as String?) == 'active',
      quickFacts: ((j['quickFacts'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()))) ?? const {},
      rawSections: (j['sections'] as Map?)?.cast<String, dynamic>() ?? const {},
      skemaUrl: j['skemaUrl'] as String?,
    );
  }
}

class ProductKnowledge {
  final List<PkCategory> categories;
  final List<PkProduct> products;
  const ProductKnowledge({required this.categories, required this.products});

  PkCategory categoryOf(PkProduct p) =>
      categories.firstWhere((c) => c.id == p.categoryId,
          orElse: () => const PkCategory(id: 'lainnya', name: 'Lainnya', icon: 'shapes', color: Color(0xFF8C97A6)));

  int productCount(String categoryId) => products.where((p) => p.categoryId == categoryId).length;
  int activeCount(String categoryId) => products.where((p) => p.categoryId == categoryId && p.active).length;
}

/// Loader katalog Product Knowledge. Basis JSON kurasi di-cache sekali per sesi;
/// overlay produk admin di-fetch ulang tiap pemanggilan agar perubahan tampil.
class ProductKnowledgeRepository {
  ProductKnowledgeRepository._();
  static final ProductKnowledgeRepository instance = ProductKnowledgeRepository._();

  static const String _prefsKey = 'mbis.product_knowledge.cache';

  /// API-first: DB (backend) adalah sumber tunggal katalog. Ambil kategori + produk,
  /// cache ke SharedPreferences untuk offline. Bila API gagal → cache lokal; bila
  /// belum ada cache → asset bawaan (fallback offline first-run).
  Future<ProductKnowledge> load(MasterDataRepository masterData) async {
    try {
      final cats = await masterData.getProductCategories();
      final prods = await masterData.getProducts(activeOnly: false);
      final map = _apiToMap(cats, prods);
      await _writeCache(map);
      return _parse(map);
    } catch (_) {
      final cached = await _readCache();
      if (cached != null) return cached;
      return _loadAsset();
    }
  }

  ProductKnowledge _parse(Map<String, dynamic> j) {
    final cats = (j['categories'] as List)
        .map((e) => PkCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    final prods = (j['products'] as List)
        .map((e) => PkProduct.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProductKnowledge(categories: cats, products: prods);
  }

  Future<ProductKnowledge> _loadAsset() async {
    final raw = await rootBundle.loadString('assets/product_knowledge.json');
    return _parse(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _writeCache(Map<String, dynamic> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (_) {
      /* cache best-effort */
    }
  }

  Future<ProductKnowledge?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefsKey);
      if (s == null) return null;
      return _parse(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

String _slug(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Bentuk data API (kategori + produk) → peta berbentuk asset JSON, agar bisa
/// diparse ulang oleh [PkCategory.fromJson]/[PkProduct.fromJson] & disimpan sebagai cache.
Map<String, dynamic> _apiToMap(List<ProductCategoryItem> cats, List<ProductItem> prods) => {
      'categories': [
        for (final c in cats) {'id': c.id, 'name': c.name, 'icon': c.icon, 'colorHex': c.colorHex},
      ],
      'products': [for (final p in prods) _apiProductToMap(p)],
    };

Map<String, dynamic> _apiProductToMap(ProductItem it) {
  final sections = <String, dynamic>{};
  void putText(String key, String? v) {
    final t = (v ?? '').trim();
    if (t.isNotEmpty) sections[key] = t;
  }

  void putList(String key, List<String> v) {
    if (v.isNotEmpty) sections[key] = v;
  }

  putText('deskripsi', it.description);
  putList('manfaat', it.manfaat);
  if (it.jenis.isNotEmpty) {
    sections['jenis'] = [for (final j in it.jenis) {'title': j.title, 'detail': j.detail}];
  }
  putList('biaya', it.biaya);
  putText('skemaPembayaran', it.skemaPembayaran);
  putList('pengecualian', it.pengecualian);
  putList('persyaratan', it.persyaratan);
  putList('tataCara', it.tataCara);
  putList('persyaratanKlaim', it.persyaratanKlaim);
  putList('tataCaraKlaim', it.tataCaraKlaim);
  putList('risiko', it.risiko);
  putText('simulasi', it.simulasi);

  return {
    'id': it.id,
    'slug': _slug(it.name),
    'name': it.name,
    'categoryId': it.categoryId ?? 'lainnya',
    'status': it.active ? 'active' : 'maintenance',
    'quickFacts': {
      if ((it.premi ?? '').trim().isNotEmpty) 'premi': it.premi!.trim(),
      if ((it.masaPertanggungan ?? '').trim().isNotEmpty)
        'masaPertanggungan': it.masaPertanggungan!.trim(),
      if ((it.nilaiPertanggungan ?? '').trim().isNotEmpty)
        'nilaiPertanggungan': it.nilaiPertanggungan!.trim(),
    },
    'sections': sections,
    'skemaUrl': it.skemaUrl,
  };
}

Color? _hexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Pemetaan nama ikon kategori (dari JSON) ke Material IconData.
IconData pkCategoryIcon(String name) {
  switch (name) {
    case 'shield-check': return Icons.verified_user_outlined;
    case 'trending-up': return Icons.trending_up;
    case 'building-2': return Icons.apartment_outlined;
    case 'hard-hat': return Icons.engineering_outlined;
    case 'car': return Icons.directions_car_outlined;
    case 'scale': return Icons.balance_outlined;
    case 'heart-pulse': return Icons.monitor_heart_outlined;
    case 'ship': return Icons.directions_boat_outlined;
    case 'sprout': return Icons.eco_outlined;
    case 'shapes':
    default: return Icons.category_outlined;
  }
}
