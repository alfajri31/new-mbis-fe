import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
// GPS Tracking pulls in flutter_map (heavy). Keep it out of the initial bundle:
// the screen's code is fetched on demand the first time this route is opened.
import 'gps_tracking_screen.dart' deferred as gps;

/// Route wrapper for [gps.GpsTrackingScreen]. Because the screen is a deferred
/// import, its code must be loaded before the widget can be built — so a direct
/// URL load (web refresh on /tools/gps) shows a spinner while the chunk
/// downloads, then renders the map. This is what lets the GPS tool survive a
/// refresh the same way the lighter tools do.
class GpsTrackingLoader extends StatefulWidget {
  const GpsTrackingLoader({super.key});

  @override
  State<GpsTrackingLoader> createState() => _GpsTrackingLoaderState();
}

class _GpsTrackingLoaderState extends State<GpsTrackingLoader> {
  late final Future<void> _load = gps.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.bgScreen,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return gps.GpsTrackingScreen();
      },
    );
  }
}
