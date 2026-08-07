import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../src/config/map_config.dart';
import '../../src/network/api_client.dart';
import '../../src/network/auth_image.dart';
import '../../src/visit/visit_repository.dart';
import 'visit_edit_sheet.dart';

/// Detail of a past visit: a mini map at its location, the photo, and the notes
/// the RM recorded. Opened by tapping a riwayat-kunjungan card.
///
/// Bukti kunjungan (lokasi, foto, jenis, waktu) hanya bisa dibaca; catatannya —
/// deskripsi, rencana tindak lanjut, tanggal follow-up — bisa diperbaiki RM yang
/// mencatatnya lewat tombol Edit.
///
/// Mengembalikan `true` bila kunjungan sempat diubah, supaya layar pemanggil
/// tahu perlu memuat ulang daftarnya.
Future<bool> showVisitDetail(BuildContext context, ApiClient apiClient, VisitModel v) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _VisitDetailSheet(apiClient: apiClient, visit: v),
  );
  return changed == true;
}

class _VisitDetailSheet extends StatefulWidget {
  const _VisitDetailSheet({required this.apiClient, required this.visit});

  final ApiClient apiClient;
  final VisitModel visit;

  @override
  State<_VisitDetailSheet> createState() => _VisitDetailSheetState();
}

class _VisitDetailSheetState extends State<_VisitDetailSheet> {
  late VisitModel v = widget.visit;
  bool _changed = false;

  Future<void> _edit() async {
    final updated = await showVisitEditSheet(
      context,
      VisitRepository(apiClient: widget.apiClient),
      v,
    );
    if (updated == null || !mounted) return;
    setState(() {
      v = updated;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // PopScope, bukan tombol tutup: sheet ini juga ditutup dengan swipe & tombol
    // back, dan pemanggil tetap harus tahu kalau isinya sudah berubah.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: BorderRadius.circular(100)),
                  child: Text(v.type,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                ),
                const Spacer(),
                const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(AppFormat.dateTime(v.activityDate),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            if (v.hasGps && v.lat != null && v.lng != null) ...[
              ClipRRect(
                borderRadius: AppRadius.radiusMd,
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(v.lat!, v.lng!),
                      initialZoom: 16,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: MapConfig.activeTileUrl,
                        fallbackUrl: MapConfig.osmUrl,
                        userAgentPackageName: 'com.askrindo.mbis.mobile',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(v.lat!, v.lng!),
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on, color: AppColors.errorRed, size: 40),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 13, color: AppColors.successGreen),
                  const SizedBox(width: 4),
                  Text('${v.lat!.toStringAsFixed(5)}, ${v.lng!.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (v.photoUrl != null) ...[
              GestureDetector(
                onTap: () => _showFullPhoto(context, widget.apiClient, v.photoUrl!),
                child: ClipRRect(
                  borderRadius: AppRadius.radiusMd,
                  child: AuthImage(
                      apiClient: widget.apiClient,
                      path: v.photoUrl!,
                      width: double.infinity,
                      height: 200),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text('Deskripsi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              (v.notes ?? '').isEmpty ? '-' : v.notes!,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
            // Rencana & tanggal follow-up hanya ada bila kunjungan ini membuat
            // jadwal. Tanpa jadwal, rencananya sudah dilipat backend ke dalam
            // Deskripsi di atas — jadi tidak ada yang hilang dari tampilan.
            if ((v.actionPlan ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Rencana Tindak Lanjut',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(v.actionPlan!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
            ],
            if ((v.nextFollowupDate ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Follow Up',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(AppFormat.dateTime(v.nextFollowupDate),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ],
            if (v.canEdit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Aktivitas'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }
}

/// Fullscreen photo preview — tap the thumbnail to open, pinch/drag to zoom,
/// close button or system back to dismiss. Mirrors customer_detail_screen's
/// document preview so photo viewing behaves the same everywhere in the app.
void _showFullPhoto(BuildContext context, ApiClient apiClient, String photoUrl) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: AuthImage(apiClient: apiClient, path: photoUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
