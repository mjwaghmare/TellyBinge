import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class MoviesFilterBottomSheet extends StatefulWidget {
  final String initialSort;
  final String initialProgress;

  const MoviesFilterBottomSheet({
    super.key,
    required this.initialSort,
    required this.initialProgress,
  });

  @override
  State<MoviesFilterBottomSheet> createState() => _MoviesFilterBottomSheetState();
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

  final List<String> _sortOptions = ['Last Added', 'Last Watched', 'Alphabetical'];
  final List<String> _progressOptions = [
    'All',
    'Watched',
    'Not watched',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E), // Dark grey background matching the screenshot
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Sort by Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Sort by',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
                        color: isSelected ? AppColors.primary : const Color(0xFFCCCCCC),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: Colors.black, // Dark text for both yellow and grey
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: AppSpacing.md),
          
          // Progress Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Progress List
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              itemCount: _progressOptions.length,
              separatorBuilder: (context, index) => const Divider(
                color: Colors.white12,
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
              itemBuilder: (context, index) {
                final option = _progressOptions[index];
                final isSelected = _selectedProgress == option;
                
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
                  title: Text(
                    option,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
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
                              color: Colors.white38,
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
          const Divider(color: Colors.white12, height: 1),
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
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'RESET',
                        style: TextStyle(
                          color: Colors.white70,
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
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
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
    );
  }
}
