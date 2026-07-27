import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared, consistent UI for the three non-happy states every data screen has:
/// empty, error, and loading. Keeping them here means one look across the app
/// and one place to evolve them.

/// Empty state — no data (or no search results).
/// Set [inCard] to render inside a bordered card for inline list sections.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool inCard;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.inCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppColors.grayStage.withValues(alpha: 0.4)),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpacing.lg),
          action!,
        ],
      ],
    );

    if (inCard) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: content,
      ),
    );
  }
}

/// Error state with an optional retry action.
class ErrorStateView extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const ErrorStateView({
    super.key,
    this.message = 'Gagal memuat data',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 44, color: AppColors.errorRed.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  side:
                      const BorderSide(color: AppColors.primaryNavy, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder list shown while data loads (design.md §3.15 / §6.2).
/// Pulses opacity instead of a bare spinner so long lists feel responsive.
class SkeletonList extends StatefulWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_controller),
      child: ListView.separated(
        padding: widget.padding,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _box(44, 44, 12),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _box(double.infinity, 12, 6),
                const SizedBox(height: 8),
                _box(120, 10, 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(double w, double h, double r) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.grayBg,
          borderRadius: BorderRadius.circular(r),
        ),
      );
}
