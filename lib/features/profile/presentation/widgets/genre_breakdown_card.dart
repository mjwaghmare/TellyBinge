import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/genre_stat.dart';

/// Donut chart card displaying the user's genre distribution breakdown.
class GenreBreakdownCard extends StatefulWidget {
  final List<GenreStat> stats;
  final bool isMovie;
  final VoidCallback? onRefresh;

  const GenreBreakdownCard({
    super.key,
    required this.stats,
    this.isMovie = false,
    this.onRefresh,
  });

  @override
  State<GenreBreakdownCard> createState() => _GenreBreakdownCardState();
}

class _GenreBreakdownCardState extends State<GenreBreakdownCard> {
  int _touchedIndex = -1;

  static List<Color> _palette(BuildContext context) {
    final isLight = context.isLight;
    return [
      isLight ? AppColors.lightPrimary : AppColors.primary,
      AppColors.accentBlue,
      isLight ? AppColors.lightOnSuccessContainer : AppColors.success,
      isLight ? AppColors.goldDark : AppColors.gold,
      AppColors.errorSoft,
      isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final colors = _palette(context);

    if (widget.stats.isEmpty) {
      return _buildEmptyState(context, isLight);
    }

    return SizedBox(
      height: 155,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Donut Chart with center insight
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          final newIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                          if (_touchedIndex != newIndex &&
                              newIndex >= 0 &&
                              newIndex < widget.stats.length) {
                            AppHaptics.selectionClick();
                            _touchedIndex = newIndex;
                          }
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2.0,
                    centerSpaceRadius: 38,
                    startDegreeOffset: -90,
                    sections: List.generate(widget.stats.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final radius = isTouched ? 26.0 : 20.0;
                      final stat = widget.stats[i];
                      final color = colors[i % colors.length];

                      return PieChartSectionData(
                        color: color,
                        value: stat.count.toDouble(),
                        title: '',
                        radius: radius,
                        showTitle: false,
                      );
                    }),
                  ),
                ),
                // Center text summary
                _buildCenterSummary(context, isLight, colors),
              ],
            ),
          ),
          AppSpacing.gapW12,
          // Right: Genre Legend and stats
          Expanded(
            child: _buildLegendList(context, isLight, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSummary(
    BuildContext context,
    bool isLight,
    List<Color> colors,
  ) {
    if (_touchedIndex >= 0 && _touchedIndex < widget.stats.length) {
      final touchedStat = widget.stats[_touchedIndex];
      final touchedColor = colors[_touchedIndex % colors.length];

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${touchedStat.percentage.toStringAsFixed(0)}%',
            style: AppTextStyles.smBold.copyWith(
              color: isLight
                  ? AppColors.lightTextPrimary
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            touchedStat.genre,
            style: AppTextStyles.xsBold.copyWith(
              color: touchedColor,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${touchedStat.count} ${touchedStat.count == 1 ? 'title' : 'titles'}',
            style: AppTextStyles.xs.copyWith(
              color: isLight
                  ? AppColors.lightTextSecondary
                  : AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      );
    }

    final topStat = widget.stats.first;
    final topColor = colors[0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${topStat.percentage.toStringAsFixed(0)}%',
          style: AppTextStyles.smBold.copyWith(
            color: isLight
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          topStat.genre,
          style: AppTextStyles.xsBold.copyWith(
            color: topColor,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Top Genre',
          style: AppTextStyles.xs.copyWith(
            color: isLight
                ? AppColors.lightTextTertiary
                : AppColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendList(
    BuildContext context,
    bool isLight,
    List<Color> colors,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.stats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final stat = widget.stats[index];
        final color = colors[index % colors.length];
        final isSelected = _touchedIndex == index;

        return GestureDetector(
          onTap: () {
            AppHaptics.selectionClick();
            setState(() {
              _touchedIndex = isSelected ? -1 : index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: isLight ? 0.12 : 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 9 : 7,
                  height: isSelected ? 9 : 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpacing.gapW8,
                Expanded(
                  child: Text(
                    stat.genre,
                    style: AppTextStyles.xsMedium.copyWith(
                      color: isSelected
                          ? color
                          : (isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${stat.percentage.toStringAsFixed(0)}%',
                  style: AppTextStyles.xsBold.copyWith(
                    color: isSelected
                        ? color
                        : (isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary),
                  ),
                ),
                AppSpacing.gapW4,
                Text(
                  '(${stat.count})',
                  style: AppTextStyles.xs.copyWith(
                    color: isLight
                        ? AppColors.lightTextTertiary
                        : AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isLight) {
    return Container(
      height: 145,
      width: double.infinity,
      padding: AppSpacing.allSM,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.lightSurface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? AppColors.borderLight : AppColors.borderDark,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.donut_large_rounded,
            size: 34,
            color: isLight
                ? AppColors.lightTextTertiary
                : AppColors.textTertiary,
          ),
          AppSpacing.gapH8,
          Text(
            widget.isMovie ? 'No Movie Genre Data' : 'No TV Show Genre Data',
            style: AppTextStyles.smBold.copyWith(
              color: isLight
                  ? AppColors.lightTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          AppSpacing.gapH4,
          Text(
            widget.isMovie
                ? 'Mark movies as watched to uncover your Movie Genre DNA.'
                : 'Mark episodes as watched to uncover your TV Genre DNA.',
            style: AppTextStyles.xs.copyWith(
              color: isLight
                  ? AppColors.lightTextSecondary
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
