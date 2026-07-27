import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../src/pipeline/pipeline_stage.dart';
import '../../../theme/app_theme.dart';

/// Navy header + stage stepper (P3→P2→P1→WON) with the "Stage Aktif" banner.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving).
class PipelineHeaderStepper extends StatelessWidget {
  const PipelineHeaderStepper({
    super.key,
    required this.pipeline,
    required this.stages,
    required this.currentStageIdx,
  });

  final PipelineDetailModel pipeline;
  final List<String> stages;
  final int currentStageIdx;

  @override
  Widget build(BuildContext context) {
    // Navy Header & Stage Stepper Box
    return Container(
      color: AppColors.primaryNavy,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PIPELINE',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (pipeline.product != null && pipeline.product!.isNotEmpty)
                ? pipeline.product!
                : 'Pipeline - ${pipeline.customerName ?? '-'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pipeline.customerName ?? '-',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),

          // Stepper Progress Line & Circles Stack
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              const double circleSize = 24.0;
              final int numStages = stages.length;

              // The first circle center is at circleSize / 2 (12.0)
              // The last circle center is at totalWidth - (circleSize / 2)
              final double pathWidth = totalWidth - circleSize;
              final double stepWidth = pathWidth / (numStages - 1);

              final double lineStart = circleSize / 2;
              final double activeLineEnd = lineStart + (currentStageIdx >= 0 ? currentStageIdx : 0) * stepWidth;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Line behind circles
                  Positioned(
                    left: lineStart,
                    width: pathWidth,
                    child: SizedBox(
                      height: circleSize,
                      child: Center(
                        child: Container(
                          height: 2,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  // Active line progress
                  if (currentStageIdx > 0)
                    Positioned(
                      left: lineStart,
                      width: activeLineEnd - lineStart,
                      child: SizedBox(
                        height: circleSize,
                        child: Center(
                          child: Container(
                            height: 2,
                            color: AppColors.secondaryOrange,
                          ),
                        ),
                      ),
                    ),
                  // Stepper node circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(numStages, (index) {
                      final isCompleted = index < currentStageIdx || pipeline.stage.toUpperCase() == 'WON';
                      final isActive = index == currentStageIdx && pipeline.stage.toUpperCase() != 'WON';

                      Color nodeColor = Colors.white.withValues(alpha: 0.15);
                      Widget nodeIcon = const Icon(Icons.circle, size: 8, color: Colors.white24);

                      if (isCompleted) {
                        nodeColor = AppColors.successGreen;
                        nodeIcon = const Icon(Icons.check, size: 12, color: Colors.white);
                      } else if (isActive) {
                        nodeColor = AppColors.secondaryOrange;
                        nodeIcon = Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        );
                      }

                      return Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          color: nodeColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? Colors.white : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(child: nodeIcon),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),

          // Stepper Labels Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stages.length, (index) {
              final stageName = stages[index];
              final isCompleted = index < currentStageIdx || pipeline.stage.toUpperCase() == 'WON';
              final isActive = index == currentStageIdx && pipeline.stage.toUpperCase() != 'WON';
              Color labelColor = Colors.white30;

              if (isCompleted) {
                labelColor = AppColors.successGreen;
              } else if (isActive) {
                labelColor = AppColors.secondaryOrange;
              }

              return Container(
                width: 24, // Align exactly with the circle width
                alignment: Alignment.center,
                child: Text(
                  stageName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                    color: labelColor,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Active Detail Stage banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusSm,
            ),
            child: Row(
              children: [
                const Text(
                  'Stage Aktif: ',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Expanded(
                  child: Text(
                    pipeline.subStage != null
                        ? '${pipeline.stage} · ${PipelineStages.labelOf(pipeline.subStage)}'
                        : pipeline.stage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
