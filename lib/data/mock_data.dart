// Static reference content for screens that do not yet have a backend
// (S-110 Product Knowledge, in-app notifications). This is fixed catalog/notice
// content, NOT a data-layer mock — customer/pipeline/agent data all come from
// the API. Replace with a repository/endpoint when those features are backed.

class NotificationItem {
  final String id;
  final String type; // 'info', 'warning', 'success', 'error'
  final String title;
  final String body;
  final String time;
  final bool read;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.read,
  });
}

class Product {
  final String id;
  final String name;
  final String lini;
  final String icon;
  final String description;
  final List<String> manfaat;

  const Product({
    required this.id,
    required this.name,
    required this.lini,
    required this.icon,
    required this.description,
    required this.manfaat,
  });
}

const List<NotificationItem> mockNotifications = [
  NotificationItem(
    id: 'n-001',
    type: 'warning',
    title: 'Pipeline Mendekati Closing',
    body: 'Pipeline "Surety Bond KSO Garuda-Angkasa" estimasi closing dalam 7 hari. Segera update progress.',
    time: '2 jam lalu',
    read: false,
  ),
  NotificationItem(
    id: 'n-002',
    type: 'info',
    title: 'Update Regulasi OJK',
    body: 'POJK No. 2/POJK.05/2024 tentang penyelenggaraan usaha perusahaan asuransi telah diterbitkan.',
    time: '5 jam lalu',
    read: false,
  ),
  NotificationItem(
    id: 'n-003',
    type: 'error',
    title: 'Peringatan Blacklist',
    body: 'PT Maju Mundur terdeteksi dalam daftar tunggakan ACS. Transaksi tidak dapat dilanjutkan.',
    time: 'Kemarin',
    read: true,
  ),
  NotificationItem(
    id: 'n-004',
    type: 'success',
    title: 'Pipeline Won!',
    body: 'Pipeline "KSO Telkom-Indosat Program Digitalisasi" berhasil Won. Premi Rp 1.500.000.000. Selamat!',
    time: '2 hari lalu',
    read: true,
  ),
  NotificationItem(
    id: 'n-005',
    type: 'info',
    title: 'Pengingat Follow-up',
    body: 'Jadwal kunjungan PT Astra International telah lewat (20 Jun 2026). Segera reschedule.',
    time: '3 hari lalu',
    read: true,
  ),
];

const List<Product> mockProducts = [
  Product(
    id: 'pr-001',
    name: 'Asuransi Kredit Bank',
    lini: 'Asuransi Kredit',
    icon: '🏦',
    description: 'Perlindungan bagi perbankan atas risiko gagal bayar debitur kredit',
    manfaat: ['Perlindungan kredit korporasi', 'Kredit UMKM', 'Kredit konsumtif', 'Fasilitas revolving'],
  ),
  Product(
    id: 'pr-002',
    name: 'Asuransi Kredit Perdagangan',
    lini: 'Asuransi Kredit',
    icon: '📦',
    description: 'Melindungi eksportir/importir dari risiko gagal bayar mitra dagang',
    manfaat: ['Buyer risk protection', 'Country risk coverage', 'Short-term trade credit', 'LC discounting'],
  ),
  Product(
    id: 'pr-003',
    name: 'Surety Bond',
    lini: 'Penjaminan',
    icon: '🏗️',
    description: 'Jaminan pemenuhan kewajiban kontraktor kepada pemilik proyek',
    manfaat: ['Bid Bond', 'Performance Bond', 'Advance Payment Bond', 'Maintenance Bond'],
  ),
  Product(
    id: 'pr-004',
    name: 'Customs Bond',
    lini: 'Penjaminan',
    icon: '✈️',
    description: 'Jaminan atas bea masuk & pajak impor kepada Direktorat Jenderal Bea Cukai',
    manfaat: ['Importir Umum', 'Kawasan Berikat', 'KITE', 'Pusat Logistik Berikat'],
  ),
  Product(
    id: 'pr-005',
    name: 'Kontra Bank Garansi',
    lini: 'Penjaminan',
    icon: '🏛️',
    description: 'Counter guarantee atas bank garansi yang diterbitkan perbankan',
    manfaat: ['Efisiensi biaya jaminan', 'Fleksibilitas plafon', 'Proses cepat', 'Multi-bank'],
  ),
  Product(
    id: 'pr-006',
    name: 'Asuransi Umum',
    lini: 'Asuransi Umum',
    icon: '🛡️',
    description: 'Perlindungan aset dan properti dari berbagai risiko umum',
    manfaat: ['Property All Risk', 'CAR/EAR', 'Marine Cargo', 'Liability'],
  ),
];
