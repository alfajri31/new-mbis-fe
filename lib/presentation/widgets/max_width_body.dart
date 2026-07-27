import 'package:flutter/material.dart';

/// Caps content width and centres it so a screen's body doesn't stretch
/// edge-to-edge on desktop; on narrower windows it just fills the width.
/// Mirrors the Center + ConstrainedBox pattern used across the responsive
/// screens (default 800 matches the admin console list widths).
class MaxWidthBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const MaxWidthBody({super.key, required this.child, this.maxWidth = 800});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
