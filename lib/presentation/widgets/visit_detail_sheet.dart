import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../src/config/map_config.dart';
import '../../src/network/api_client.dart';
import '../../src/network/auth_image.dart';
import '../../src/visit/visit_repository.dart';

/// Read-only detail of a past visit: a mini map at its location, the photo, and
/// the notes the RM recorded. Opened by tapping a riwayat-kunjungan card.
void showVisitDetail(BuildContext context, ApiClient apiClient, VisitModel v) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => DraggableScrollableSheet(
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
                onTap: () => _showFullPhoto(context, apiClient, v.photoUrl!),
                child: ClipRRect(
                  borderRadius: AppRadius.radiusMd,
                  child: AuthImage(apiClient: apiClient, path: v.photoUrl!, width: double.infinity, height: 200),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
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
