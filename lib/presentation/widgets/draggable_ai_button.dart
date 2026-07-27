import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

/// AssistiveTouch-style floating button: drag it anywhere, it snaps to the nearest
/// horizontal edge on release, and tapping it jumps straight to the AI assistant.
///
/// High sensitivity: uses a raw [Listener] (pointer events) so the button tracks the
/// finger immediately with NO drag slop. Position lives in a [ValueNotifier], so only
/// a tiny [ValueListenableBuilder] rebuilds while dragging — the button subtree is
/// built once and reused, with no per-frame layout pass.
class DraggableAiButton extends StatefulWidget {
  const DraggableAiButton({super.key});

  @override
  State<DraggableAiButton> createState() => _DraggableAiButtonState();
}

class _DraggableAiButtonState extends State<DraggableAiButton> {
  static const double _size = 56;
  static const double _margin = 12;
  static const double _tapSlop = 8; // movement under this = a tap, not a drag

  final ValueNotifier<Offset?> _pos = ValueNotifier<Offset?>(null);
  final ValueNotifier<bool> _pressed = ValueNotifier<bool>(false);
  double _moved = 0;

  @override
  void dispose() {
    _pos.dispose();
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        Offset clamp(Offset p) => Offset(
              p.dx.clamp(_margin, w - _size - _margin),
              p.dy.clamp(_margin, h - _size - _margin),
            );
        _pos.value ??= clamp(Offset(w - _size - _margin, h - _size - 24));

        // Built once, reused across position updates.
        final button = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            _moved = 0;
            _pressed.value = true;
          },
          onPointerMove: (e) {
            _moved += e.delta.distance;
            _pos.value = clamp(_pos.value! + e.delta);
          },
          onPointerUp: (_) {
            _pressed.value = false;
            if (_moved < _tapSlop) {
              context.go('/tools/assistant');
              return;
            }
            final cur = _pos.value!;
            final snapX = cur.dx + _size / 2 < w / 2 ? _margin : w - _size - _margin;
            _pos.value = Offset(snapX, cur.dy);
          },
          onPointerCancel: (_) => _pressed.value = false,
          child: _button(),
        );

        return ValueListenableBuilder<Offset?>(
          valueListenable: _pos,
          builder: (context, pos, child) {
            final p = clamp(pos ?? Offset(w - _size - _margin, h - _size - 24));
            return Stack(children: [Positioned(left: p.dx, top: p.dy, child: child!)]);
          },
          child: button,
        );
      },
    );
  }

  Widget _button() => RepaintBoundary(
        child: ValueListenableBuilder<bool>(
          valueListenable: _pressed,
          builder: (context, pressed, child) => AnimatedScale(
            scale: pressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: child,
          ),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Borderless gradient disc with a soft navy glow — the mascot pops on it.
                Container(
                  width: _size,
                  height: _size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryNavyLight,
                        AppColors.primaryNavy,
                        AppColors.primaryNavyDark,
                      ],
                    ),
                    boxShadow: [
                      // Coloured glow for depth…
                      BoxShadow(
                        color: Color(0x590D2C54),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: Offset(0, 6),
                      ),
                      // …plus a tight contact shadow.
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(
                    'assets/images/maskot.png',
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.smart_toy, color: Colors.white, size: 26),
                  ),
                ),
                // Little "AI spark" badge for flair.
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.secondaryOrange, Color(0xFFF7A45C)],
                      ),
                      border: Border.all(color: AppColors.surfaceWhite, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33F2843A), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
