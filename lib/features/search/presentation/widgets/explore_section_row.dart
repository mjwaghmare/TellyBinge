import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'explore_poster_card.dart';

/// Card geometry shared by every Explore row, matching the grid's 0.52 aspect.
const double _cardWidth = 112;
const double _rowHeight = _cardWidth / 0.52;

/// Every row shows at most this many titles; See All appears when there are
/// more behind them.
const int exploreRowMaxItems = 5;

class ExploreSectionHeader extends StatelessWidget {
  const ExploreSectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.posterHeader.copyWith(
                fontSize: 24,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: () {
                AppHaptics.lightImpact();
                onSeeAll!();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See All', style: AppTextStyles.smBold),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Header plus a horizontal poster row. Shows a skeleton while [isLoading].
/// Callers skip building it entirely for an empty, loaded row.
class ExploreSectionRow extends StatelessWidget {
  const ExploreSectionRow({
    super.key,
    required this.title,
    required this.items,
    required this.defaultType,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.onSeeAll,
    this.storageId,
  });

  /// Keys the row's horizontal scroll offset. Without a distinct key every row
  /// shares one PageStorage slot, so a row scrolled back into view would
  /// restore another row's offset. Defaults to [title].
  final String? storageId;

  final String title;
  final List<dynamic> items;
  final String defaultType;
  final bool isLoading;

  /// Adds a spinner after the last poster while the row tops itself up.
  final bool isLoadingMore;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final shown = isLoading
        ? _skeletonItems(defaultType)
        : items.take(exploreRowMaxItems).toList(growable: false);
    final showSpinner =
        isLoadingMore && !isLoading && items.length < exploreRowMaxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExploreSectionHeader(
          title: title,
          onSeeAll: !isLoading && items.length > exploreRowMaxItems
              ? onSeeAll
              : null,
        ),
        Skeletonizer(
          enabled: isLoading,
          child: SizedBox(
            height: _rowHeight,
            child: ListView.separated(
              key: PageStorageKey<String>(
                'explore_row_${defaultType}_${storageId ?? title}',
              ),
              scrollDirection: Axis.horizontal,
              physics: isLoading
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: shown.length + (showSpinner ? 1 : 0),
              separatorBuilder: (_, _) => AppSpacing.gapW8,
              itemBuilder: (context, index) {
                if (index == shown.length) {
                  return const SizedBox(
                    key: ValueKey('loading_more'),
                    width: _cardWidth / 2,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }
                final item = shown[index];
                return SizedBox(
                  key: ValueKey('${defaultType}_${item['id']}'),
                  width: _cardWidth,
                  child: ExplorePosterCard(
                    item: item,
                    defaultType: defaultType,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Netflix-style ranked row: a tall outlined rank number with the poster
/// pressed up against it, no title or rating underneath.
class ExploreTopWeekRow extends StatefulWidget {
  const ExploreTopWeekRow({
    super.key,
    required this.title,
    required this.items,
    required this.defaultType,
    this.isLoading = false,
  });

  final String title;
  final List<dynamic> items;
  final String defaultType;
  final bool isLoading;

  @override
  State<ExploreTopWeekRow> createState() => _ExploreTopWeekRowState();
}

class _ExploreTopWeekRowState extends State<ExploreTopWeekRow> {
  static const double _posterWidth = _cardWidth;
  static const double _posterHeight = _posterWidth * 1.5;

  /// Bebas Neue's cap height as a fraction of its font size.
  static const double _capHeightRatio = 0.7;

  /// Digits stand as tall as the poster.
  static const double _fontSize = _posterHeight / _capHeightRatio;

  /// Share of each number's slot the poster covers, as in Netflix's row: the
  /// digit's right side disappears behind the poster.
  static const double _overlapRatio = 0.3;

  /// Laid-out rank numbers, reused across builds. Laying out five 240px
  /// glyphs on every rebuild (e.g. each time the row scrolls back into
  /// view) showed up as scroll jank.
  List<TextPainter>? _numbers;
  double _slotWidth = 0;
  Brightness? _numbersBrightness;

  @override
  void initState() {
    super.initState();
    // Bebas Neue is fetched at runtime, so the first layout may measure a
    // fallback font. Re-measure once real fonts arrive.
    PaintingBinding.instance.systemFonts.addListener(_invalidateNumbers);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_invalidateNumbers);
    _disposeNumbers();
    super.dispose();
  }

  void _invalidateNumbers() {
    if (!mounted) return;
    setState(_disposeNumbers);
  }

  void _disposeNumbers() {
    for (final painter in _numbers ?? const <TextPainter>[]) {
      painter.dispose();
    }
    _numbers = null;
  }

  List<TextPainter> _numbersFor(Brightness brightness) {
    if (_numbers != null && _numbersBrightness == brightness) return _numbers!;
    _disposeNumbers();
    final isLight = brightness == Brightness.light;
    final style = AppTextStyles.posterTitle.copyWith(
      fontSize: _fontSize,
      height: 1,
      letterSpacing: 0,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = isLight
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.45),
    );
    final numbers = [
      for (var rank = 1; rank <= exploreRowMaxItems; rank++)
        TextPainter(
          text: TextSpan(text: '$rank', style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(),
    ];
    // One slot width for every rank, sized to the widest digit, so each
    // number sits flush against its poster and a narrow "1" leaves space on
    // its left rather than pulling its poster closer.
    _slotWidth = numbers.map((n) => n.width).reduce((a, b) => a > b ? a : b);
    _numbersBrightness = brightness;
    return _numbers = numbers;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.isLoading;
    final defaultType = widget.defaultType;
    final shown = isLoading
        ? _skeletonItems(defaultType, count: exploreRowMaxItems)
        : widget.items.take(exploreRowMaxItems).toList(growable: false);
    final numbers = _numbersFor(Theme.of(context).brightness);
    final slotWidth = _slotWidth;
    final overlap = slotWidth * _overlapRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExploreSectionHeader(title: widget.title),
        Skeletonizer(
          enabled: isLoading,
          child: SizedBox(
            height: _posterHeight,
            child: ListView.separated(
              key: PageStorageKey<String>('explore_row_${defaultType}_top'),
              scrollDirection: Axis.horizontal,
              physics: isLoading
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: shown.length,
              separatorBuilder: (_, _) => AppSpacing.gapW8,
              itemBuilder: (context, index) {
                final item = shown[index];
                final rank = '${index + 1}';
                final name = item['name'] ?? item['title'] ?? '';
                return SizedBox(
                  key: ValueKey('top_${defaultType}_${item['id']}'),
                  width: slotWidth - overlap + _posterWidth,
                  // The title isn't shown here, so it goes in the label.
                  child: Semantics(
                    container: true,
                    label: isLoading ? null : 'Rank $rank, $name',
                    child: Stack(
                      children: [
                        // Left out while loading: the outline would tower over
                        // the shimmering poster placeholders.
                        if (!isLoading)
                          Positioned.fill(
                            child: ExcludeSemantics(
                              child: CustomPaint(
                                painter: _RankNumberPainter(
                                  number: numbers[index],
                                  slotWidth: slotWidth,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          width: _posterWidth,
                          child: ExplorePosterCard(
                            item: item,
                            defaultType: defaultType,
                            posterOnly: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a rank number right-aligned in its slot, with its baseline on the
/// poster's bottom edge so the digit spans the poster's height.
class _RankNumberPainter extends CustomPainter {
  _RankNumberPainter({required this.number, required this.slotWidth});

  final TextPainter number;
  final double slotWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = number.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    number.paint(
      canvas,
      Offset(slotWidth - number.width, size.height - baseline),
    );
  }

  /// Numbers are cached, so an unchanged one is the identical painter.
  @override
  bool shouldRepaint(_RankNumberPainter oldDelegate) =>
      oldDelegate.slotWidth != slotWidth ||
      !identical(oldDelegate.number, number);
}

List<Map<String, dynamic>> _skeletonItems(
  String defaultType, {
  int count = exploreRowMaxItems,
}) {
  return List.generate(
    count,
    (index) => {
      if (defaultType == 'tv') 'name': 'Loading Title',
      if (defaultType != 'tv') 'title': 'Loading Title',
      'vote_average': 9.9,
      'id': -1 - index,
    },
  );
}
