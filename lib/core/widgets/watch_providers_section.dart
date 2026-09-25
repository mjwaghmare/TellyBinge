import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/app_haptics.dart';
import '../services/deep_link_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_snackbar.dart';

enum WatchProviderCategory {
  stream('Stream'),
  free('Free'),
  rent('Rent'),
  buy('Buy');

  final String label;
  const WatchProviderCategory(this.label);
}

/// A section displaying where a Movie or TV Show is available to watch
/// (Stream, Free, Rent, Buy), powered by TMDB's watch provider data.
class WatchProvidersSection extends StatefulWidget {
  final Map<String, dynamic>? watchProvidersData;
  final String? mediaTitle;

  const WatchProvidersSection({
    super.key,
    required this.watchProvidersData,
    this.mediaTitle,
  });

  /// Returns true if the TMDB watch/providers map contains at least one provider
  /// in the user's locale, US, or any supported country.
  static bool hasProviders(dynamic data) {
    if (data is! Map<String, dynamic>) return false;
    final results = data['results'];
    if (results is! Map<String, dynamic> || results.isEmpty) return false;

    final deviceCountry =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    if (deviceCountry != null &&
        results[deviceCountry] is Map<String, dynamic> &&
        _hasProvidersInCountry(results[deviceCountry] as Map<String, dynamic>)) {
      return true;
    }

    if (results['US'] is Map<String, dynamic> &&
        _hasProvidersInCountry(results['US'] as Map<String, dynamic>)) {
      return true;
    }

    for (final val in results.values) {
      if (val is Map<String, dynamic> && _hasProvidersInCountry(val)) {
        return true;
      }
    }
    return false;
  }

  /// Helper to safely inspect whether a country map has any providers
  static bool _hasProvidersInCountry(Map<String, dynamic>? countryData) {
    if (countryData == null) return false;
    final flatrate = countryData['flatrate'];
    final free = countryData['free'];
    final ads = countryData['ads'];
    final rent = countryData['rent'];
    final buy = countryData['buy'];

    return (flatrate is List && flatrate.isNotEmpty) ||
        (free is List && free.isNotEmpty) ||
        (ads is List && ads.isNotEmpty) ||
        (rent is List && rent.isNotEmpty) ||
        (buy is List && buy.isNotEmpty);
  }

  @override
  State<WatchProvidersSection> createState() => _WatchProvidersSectionState();
}

class _WatchProvidersSectionState extends State<WatchProvidersSection> {
  WatchProviderCategory? _selectedCategory;

  @override
  void didUpdateWidget(covariant WatchProvidersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.watchProvidersData != oldWidget.watchProvidersData) {
      setState(() {
        _selectedCategory = null;
      });
    }
  }

  /// Deduplicates providers in a list by `provider_id` or `provider_name`,
  /// normalizes brand names (e.g. JioCinema & Hotstar -> JioHotstar),
  /// and sorts them by `display_priority` ascending so major services appear first.
  static List<Map<String, dynamic>> _deduplicateAndSortProviders(
    List<dynamic>? list,
  ) {
    if (list == null || list.isEmpty) return const [];
    final seenKeys = <dynamic>{};
    final result = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final rawId = (item['provider_id'] as num?)?.toInt();
        final rawName = item['provider_name'] as String? ?? '';
        final normalizedName = DeepLinkService.normalizeProviderName(
          rawId,
          rawName,
        );

        // Canonicalize key so JioCinema (220) and Hotstar (122) merge to single key
        final canonicalKey =
            (rawId == DeepLinkService.hotstarId ||
                    rawId == DeepLinkService.jioCinemaId)
                ? DeepLinkService.hotstarId
                : (rawId ?? normalizedName);

        if (seenKeys.add(canonicalKey)) {
          final mappedItem = Map<String, dynamic>.from(item);
          mappedItem['provider_name'] = normalizedName;
          result.add(mappedItem);
        }
      }
    }

    result.sort((a, b) {
      final pA = (a['display_priority'] as num?)?.toInt() ?? 999;
      final pB = (b['display_priority'] as num?)?.toInt() ?? 999;
      return pA.compareTo(pB);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final rawResults = widget.watchProvidersData?['results'];
    if (rawResults is! Map<String, dynamic> || rawResults.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine target country code:
    // 1. Device locale country
    // 2. Fallback to US
    // 3. Fallback to first available country with data
    final deviceCountry =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

    String? targetCountry;
    if (deviceCountry != null &&
        rawResults[deviceCountry] is Map<String, dynamic> &&
        WatchProvidersSection._hasProvidersInCountry(
          rawResults[deviceCountry] as Map<String, dynamic>,
        )) {
      targetCountry = deviceCountry;
    } else if (rawResults['US'] is Map<String, dynamic> &&
        WatchProvidersSection._hasProvidersInCountry(
          rawResults['US'] as Map<String, dynamic>,
        )) {
      targetCountry = 'US';
    } else {
      for (final entry in rawResults.entries) {
        if (entry.value is Map<String, dynamic> &&
            WatchProvidersSection._hasProvidersInCountry(
              entry.value as Map<String, dynamic>,
            )) {
          targetCountry = entry.key;
          break;
        }
      }
    }

    if (targetCountry == null) {
      return const SizedBox.shrink();
    }

    final countryData = rawResults[targetCountry] as Map<String, dynamic>;

    // Parse categories
    final streamList = _deduplicateAndSortProviders(
      countryData['flatrate'] as List?,
    );
    final freeList = _deduplicateAndSortProviders([
      ...?countryData['free'] as List?,
      ...?countryData['ads'] as List?,
    ]);
    final rentList = _deduplicateAndSortProviders(
      countryData['rent'] as List?,
    );
    final buyList = _deduplicateAndSortProviders(
      countryData['buy'] as List?,
    );

    // Build available category map
    final Map<WatchProviderCategory, List<Map<String, dynamic>>> categoryMap = {};
    if (streamList.isNotEmpty) categoryMap[WatchProviderCategory.stream] = streamList;
    if (freeList.isNotEmpty) categoryMap[WatchProviderCategory.free] = freeList;
    if (rentList.isNotEmpty) categoryMap[WatchProviderCategory.rent] = rentList;
    if (buyList.isNotEmpty) categoryMap[WatchProviderCategory.buy] = buyList;

    if (categoryMap.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ensure selected category is valid
    final activeCategory = (_selectedCategory != null &&
            categoryMap.containsKey(_selectedCategory))
        ? _selectedCategory!
        : categoryMap.keys.first;

    final currentProviders = categoryMap[activeCategory] ?? const [];

    final isLight = context.isLight;
    final cardBorderColor = isLight ? AppColors.borderLight : AppColors.borderDark;
    final cardBgColor = isLight ? AppColors.lightSurface : AppColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'WHERE TO WATCH',
                  style: AppTextStyles.posterHeader.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                AppSpacing.gapW8,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: cardBorderColor,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    targetCountry,
                    style: AppTextStyles.xs.copyWith(
                      color: context.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'via JustWatch',
              style: AppTextStyles.xsMedium.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
        AppSpacing.gapH12,

        // Category Filter Tabs (if more than 1 category exists)
        if (categoryMap.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categoryMap.keys.map((cat) {
                final isSelected = cat == activeCategory;
                final count = categoryMap[cat]!.length;

                final chipBg = isSelected
                    ? (isLight
                        ? AppColors.lightPrimaryContainer
                        : AppColors.primary.withValues(alpha: 0.18))
                    : Colors.transparent;

                final chipBorder = isSelected
                    ? (isLight ? AppColors.lightPrimary : AppColors.primary)
                    : cardBorderColor;

                final chipTextColor = isSelected
                    ? (isLight
                        ? AppColors.lightOnPrimaryContainer
                        : AppColors.primaryLight)
                    : context.textSecondary;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (_selectedCategory != cat) {
                        AppHaptics.selectionClick();
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: chipBorder,
                          width: isSelected ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat.label,
                            style: AppTextStyles.smMedium.copyWith(
                              color: chipTextColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          AppSpacing.gapW4,
                          Text(
                            '($count)',
                            style: AppTextStyles.xs.copyWith(
                              color: isSelected
                                  ? chipTextColor.withValues(alpha: 0.8)
                                  : context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          AppSpacing.gapH16,
        ],

        // Provider Cards Horizontal List with comfortable height for two-line text
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: currentProviders.length,
            separatorBuilder: (context, index) => AppSpacing.gapW12,
            itemBuilder: (context, index) {
              final provider = currentProviders[index];
              final providerName =
                  provider['provider_name'] as String? ?? 'Provider';
              final logoPath = provider['logo_path'] as String?;
              final providerId =
                  (provider['provider_id'] as num?)?.toInt() ?? 0;
              final fallbackWebUrl = countryData['link'] as String?;

              return _buildProviderTile(
                providerId: providerId,
                name: providerName,
                logoPath: logoPath,
                fallbackWebUrl: fallbackWebUrl,
                isLight: isLight,
                cardBorderColor: cardBorderColor,
                cardBgColor: cardBgColor,
                textSecondary: context.textSecondary,
                textTertiary: context.textTertiary,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProviderTile({
    required int providerId,
    required String name,
    required String? logoPath,
    required String? fallbackWebUrl,
    required bool isLight,
    required Color cardBorderColor,
    required Color cardBgColor,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    final String? logoUrl;
    if (logoPath != null && logoPath.isNotEmpty) {
      final cleanPath = logoPath.startsWith('/') ? logoPath : '/$logoPath';
      logoUrl = '${AppConstants.tmdbBaseImageUrl}w154$cleanPath';
    } else {
      logoUrl = null;
    }

    return Semantics(
      label: 'Watch on $name',
      button: true,
      child: Tooltip(
        message: 'Watch on $name',
        child: SizedBox(
          width: 78,
          child: GestureDetector(
            onTap: () async {
              await AppHaptics.lightImpact();
              final success = await DeepLinkService.launchProvider(
                providerId: providerId,
                providerName: name,
                title: widget.mediaTitle ?? '',
                fallbackWebUrl: fallbackWebUrl,
              );
              if (!success && mounted) {
                AppSnackbar.showInfo(
                  context,
                  'Could not open $name directly',
                );
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cardBorderColor,
                          width: 1,
                        ),
                        boxShadow: isLight ? AppColors.lightCardShadow : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: logoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isLight
                                      ? AppColors.lightSurfaceElevated
                                      : AppColors.surfaceElevated,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: isLight
                                      ? AppColors.lightSurfaceElevated
                                      : AppColors.surfaceElevated,
                                  child: Icon(
                                    Icons.live_tv,
                                    size: 24,
                                    color: textTertiary,
                                  ),
                                ),
                              )
                            : Container(
                                color: isLight
                                    ? AppColors.lightSurfaceElevated
                                    : AppColors.surfaceElevated,
                                child: Icon(
                                  Icons.live_tv,
                                  size: 24,
                                  color: textTertiary,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: isLight
                              ? AppColors.lightSurfaceElevated
                              : AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cardBorderColor,
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 10,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH4,
                Text(
                  name,
                  style: AppTextStyles.xsMedium.copyWith(
                    color: textSecondary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
