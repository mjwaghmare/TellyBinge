import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class MoviesFilterBottomSheet extends StatefulWidget {
  final String initialSort;
  final String initialProgress;

  const MoviesFilterBottomSheet({
    super.key,
    required this.initialSort,
    required this.initialProgress,
  });

  @override
  State<MoviesFilterBottomSheet> createState() =>
      _MoviesFilterBottomSheetState();
}

class _MoviesFilterBottomSheetState extends State<MoviesFilterBottomSheet> {
  late String _selectedSort;
  late String _selectedProgress;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
    _selectedProgress = widget.initialProgress;
  }

  final List<String> _sortOptions = [
    'Last Added',
    'Last Watched',
    'Alphabetical',
  ];
  final List<String> _progressOptions = [
    'All',
    'Not watched',
    'Upcoming',
    'Watched',
  ];

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6,
      child: Material(
        color:
            Theme.of(context).bottomSheetTheme.backgroundColor ??
            context.adaptiveColor(
              light: Colors.white,
              dark: AppColors.surfaceDarkAlt,
            ), // Dark grey background matching the screenshot
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSort = option;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : context.adaptiveColor(
                                  light: Colors.grey.shade200,
                                  dark: AppColors.surfaceElevated,
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
                      style: TextStyle(
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
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.black,
                            ),
                          )
                        : Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.black38
                                    : Colors.white38,
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
                            _selectedSort = 'Last Added'; // Reset default
                            _selectedProgress = 'All';
                          });
                          Navigator.pop(context, {
                            'sort': 'Last Added',
                            'progress': 'All',
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: context.adaptiveColor(
                              light: Colors.grey.shade400,
                              dark: Colors.white54,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.xl),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'RESET',
                          style: TextStyle(
                            color: context.adaptiveColor(
                              light: Colors.black87,
                              dark: Colors.white70,
                            ),
                            fontWeight: FontWeight.bold,
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'APPLY',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
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
