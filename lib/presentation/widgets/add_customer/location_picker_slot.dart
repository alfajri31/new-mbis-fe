import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Slot bergaris putus-putus (dashed) untuk memilih lokasi di peta / geotag.
/// Menampilkan koordinat/alamat terpilih; aksi tap diteruskan lewat [onTap].
/// Murni presentational — diekstrak dari `add_customer_screen.dart`
/// (behavior-preserving); data via constructor, aksi via callback.
class LocationPickerSlot extends StatelessWidget {
  const LocationPickerSlot({
    super.key,
    required this.locationCoordinate,
    required this.locationAddress,
    required this.onTap,
  });

  final String locationCoordinate;
  final String locationAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: DashedRectPainter(
          color: locationCoordinate.isNotEmpty
              ? AppColors.successGreen
              : AppColors.grayStage,
          strokeWidth: 1.0,
          gap: 5.0,
        ),
        child: Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bgScreen,
            borderRadius: AppRadius.radiusMd,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                locationCoordinate.isNotEmpty
                    ? Icons.location_on
                    : Icons.map_outlined,
                color: locationCoordinate.isNotEmpty
                    ? AppColors.successGreen
                    : AppColors.grayStage,
                size: 24,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  locationCoordinate.isNotEmpty
                      ? (locationAddress.isNotEmpty
                            ? locationAddress
                            : locationCoordinate)
                      : 'Pilih Lokasi di Peta',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: locationCoordinate.isNotEmpty
                        ? AppColors.successGreen
                        : AppColors.textSecondary,
                    fontWeight: locationCoordinate.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (locationCoordinate.isNotEmpty && locationAddress.isNotEmpty)
                Text(
                  locationCoordinate,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
