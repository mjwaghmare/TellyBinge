import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

class ShowsFilterBottomSheet extends StatefulWidget {
  final String initialSort;
  final String initialProgress;

  const ShowsFilterBottomSheet({
    super.key,
    required this.initialSort,
    required this.initialProgress,
  });

  @override
  State<ShowsFilterBottomSheet> createState() => _ShowsFilterBottomSheetState();
}

class _ShowsFilterBottomSheetState extends State<ShowsFilterBottomSheet> {
  late String _selectedSort;
  late String _selectedProgress;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
    _selectedProgress = widget.initialProgress;
  }

  final List<String> _sortOptions = [
    'Last added',
    'Last watched',
    'Alphabetical',
  ];
  final List<String> _progressOptions = [
    'All',
    'Watching',
    "Haven't started",
    'Up to date',
    'Finished',
    'Stopped',
    'Favorites',
  ];

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6,
      child: Material(
        color: AppBottomSheet.backgroundColor(context),
        borderRadius: AppBottomSheet.borderRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            const AppSheetHandle(),
            const SizedBox(height: AppSpacing.md),
            // Sort by Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Sort by',
                style: AppTextStyles.mdBold.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: _sortOptions.map((option) {
                  final isSelected = _selectedSort == option;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSort = option;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : context.adaptiveColor(
                                  light: AppColors.lightSurfaceElevated,
                                  dark: AppColors.surfaceLight,
                                ),
                          borderRadius: BorderRadius.circular(AppSpacing.xl),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.chipBorder(context),
                          ),
                        ),
                        child: Text(
                          option,
                          style:
                              (isSelected
                                      ? AppTextStyles.smBold
                                      : AppTextStyles.smMedium)
                                  .withColor(
                                    isSelected
                                        ? AppColors.textOnPrimary
                                        : (Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color ??
                                              AppColors.textPrimary),
                                  ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: AppSpacing.md),

            // Progress Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Progress',
                style: AppTextStyles.mdBold.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Progress List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                itemCount: _progressOptions.length,
                separatorBuilder: (context, index) => Divider(
                  color: Theme.of(context).dividerColor,
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
                itemBuilder: (context, index) {
                  final option = _progressOptions[index];
                  final isSelected = _selectedProgress == option;

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 0,
                    ),
                    title: Text(
                      option,
                      style: AppTextStyles.sm.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            padding: AppSpacing.allXXS,
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.adaptiveColor(
                                  light: AppColors.lightTextTertiary,
                                  dark: AppColors.textTertiary,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                    onTap: () {
                      setState(() {
                        _selectedProgress = option;
                      });
                    },
                  );
                },
              ),
            ),

            // Bottom Action Bar
            Divider(color: Theme.of(context).dividerColor, height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedSort = 'Last added'; // Reset default
                            _selectedProgress = 'All';
                          });
                          Navigator.pop(context, {
                            'sort': 'Last added',
                            'progress': 'All',
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: context.adaptiveColor(
                              light: AppColors.borderLight,
                              dark: AppColors.borderDark,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.xl),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        child: Text(
                          'RESET',
                          style: AppTextStyles.smBold.copyWith(
                            color: context.adaptiveColor(
                              light: AppColors.lightTextPrimary,
                              dark: AppColors.textSecondary,
                            ),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'sort': _selectedSort,
                            'progress': _selectedProgress,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.xl),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        child: Text(
                          'APPLY',
                          style: AppTextStyles.smBold.copyWith(
                            color: AppColors.textOnPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
