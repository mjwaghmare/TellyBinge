import 'package:flutter/material.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../data/explore_sources.dart';

/// Reusable pill filter button and bottom sheet for language selection.
///
/// Used across Explore and Surprise Me sections.
class ExploreLanguageFilterButton extends StatelessWidget {
  const ExploreLanguageFilterButton({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.height = 44.0,
    this.sheetTitle = 'Filter by Language',
    this.sheetSubtitle,
    this.languages = kExploreLanguages,
  });

  /// The active BCP-47 language code (e.g. 'hi', 'en', 'mr'), or `null` for all.
  final String? selectedLanguage;

  /// Callback when a language is selected (or `null` when 'All' is picked).
  final ValueChanged<String?> onLanguageChanged;

  /// Height of the pill button.
  final double height;

  /// Title displayed in the language bottom sheet.
  final String sheetTitle;

  /// Optional contextual subtitle displayed in the language bottom sheet.
  final String? sheetSubtitle;

  /// List of languages offered. Defaults to [kExploreLanguages].
  final List<ExploreLanguageOption> languages;

  /// Programmatically opens the language selection action sheet.
  static void showLanguageBottomSheet({
    required BuildContext context,
    required String? currentLanguage,
    required ValueChanged<String?> onLanguageSelected,
    String title = 'Filter by Language',
    String? subtitle,
    List<ExploreLanguageOption> languages = kExploreLanguages,
  }) {
    AppHaptics.lightImpact();
    final activeCode = currentLanguage ?? 'all';

    AppActionSheetAction buildOption(
      String label,
      String subtitleText,
      String value, {
      String? flag,
    }) {
      final isSelected = value == activeCode;
      return AppActionSheetAction(
        label: label,
        subtitle: subtitleText,
        iconWidget: flag != null
            ? Text(
                flag,
                style: const TextStyle(fontSize: 20),
              )
            : null,
        icon: flag == null
            ? (value == 'all' ? Icons.public_rounded : Icons.translate_rounded)
            : null,
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              )
            : const SizedBox.shrink(),
        onTap: () {
          if (isSelected) return;
          AppHaptics.lightImpact();
          onLanguageSelected(value == 'all' ? null : value);
        },
      );
    }

    AppActionSheet.show(
      context,
      title: title,
      subtitle: subtitle,
      actions: [
        buildOption('All', 'Every available language', 'all', flag: '🌐'),
        for (final l in languages)
          buildOption(l.label, l.nativeName, l.code, flag: l.flag),
      ],
    );
  }

  void _showSheet(BuildContext context) {
    showLanguageBottomSheet(
      context: context,
      currentLanguage: selectedLanguage,
      onLanguageSelected: onLanguageChanged,
      title: sheetTitle,
      subtitle: sheetSubtitle,
      languages: languages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selected = selectedLanguage != null
        ? languages.cast<ExploreLanguageOption?>().firstWhere(
            (l) => l?.code == selectedLanguage,
            orElse: () => null,
          )
        : null;
    final isFiltered = selected != null;

    return Semantics(
      button: true,
      label: isFiltered
          ? 'Language filter, currently ${selected.label}'
          : 'Language filter, currently all languages',
      child: Tooltip(
        message: 'Filter by Language',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showSheet(context),
            borderRadius: BorderRadius.circular(12.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: isFiltered
                    ? (isLight
                        ? AppColors.lightPrimaryContainer
                        : AppColors.primaryDark.withValues(alpha: 0.35))
                    : (isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isFiltered
                      ? (isLight ? AppColors.lightPrimary : AppColors.primary)
                      : (isLight ? AppColors.borderLight : AppColors.borderDark),
                  width: isFiltered ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFiltered) ...[
                    Text(selected.flag, style: const TextStyle(fontSize: 14)),
                    AppSpacing.gapW4,
                    Text(
                      selected.code.toUpperCase(),
                      style: AppTextStyles.xsBold.copyWith(
                        color: isLight
                            ? AppColors.lightPrimary
                            : AppColors.primaryLight,
                      ),
                    ),
                    AppSpacing.gapW4,
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.translate_rounded,
                      size: 16,
                      color: isLight
                          ? AppColors.lightTextSecondary
                          : AppColors.textSecondary,
                    ),
                    AppSpacing.gapW4,
                    Text(
                      'All',
                      style: AppTextStyles.xsBold.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: isLight
                          ? AppColors.lightTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
