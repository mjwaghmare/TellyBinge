import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/feedback_item.dart';
import '../widgets/feedback_card.dart';
import '../widgets/submit_feedback_sheet.dart';
import 'feedback_details_page.dart';

class FeedbackBoardPage extends StatefulWidget {
  const FeedbackBoardPage({super.key});

  @override
  State<FeedbackBoardPage> createState() => _FeedbackBoardPageState();
}

class _FeedbackBoardPageState extends State<FeedbackBoardPage> {
  late List<FeedbackItem> _items;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.from(FeedbackItem.dummyList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FeedbackItem> get _filteredItems {
    return _items.where((item) {
      // Category filter
      final matchesFilter = switch (_selectedFilter) {
        'Bug' => item.category == FeedbackCategory.bug,
        'Feature' => item.category == FeedbackCategory.feature,
        'Improvement' => item.category == FeedbackCategory.improvement,
        _ => true,
      };

      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList()
      ..sort((a, b) => b.votes.compareTo(a.votes)); // Sorted by top voted
  }

  void _handleUpvote(FeedbackItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    setState(() {
      final current = _items[index];
      if (current.isUpvoted) {
        // Remove upvote
        _items[index] = current.copyWith(
          votes: (current.votes - 1).clamp(0, 99999),
          isUpvoted: false,
        );
      } else {
        // Add upvote (and cancel downvote if any)
        final diff = current.isDownvoted ? 2 : 1;
        _items[index] = current.copyWith(
          votes: current.votes + diff,
          isUpvoted: true,
          isDownvoted: false,
        );
      }
    });
  }

  void _handleDownvote(FeedbackItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    setState(() {
      final current = _items[index];
      if (current.votes <= 0) return; // Prevent negative votes

      if (current.isDownvoted) {
        // Remove downvote
        _items[index] = current.copyWith(
          votes: current.votes + 1,
          isDownvoted: false,
        );
      } else {
        // Add downvote (and cancel upvote if any)
        final diff = current.isUpvoted ? 2 : 1;
        _items[index] = current.copyWith(
          votes: (current.votes - diff).clamp(0, 99999),
          isDownvoted: true,
          isUpvoted: false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isLight
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Feedback & Requests',
          style: AppTextStyles.lg.copyWith(
            color: isLight
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  SubmitFeedbackSheet.show(
                    context,
                    onSubmit: (newItem) {
                      setState(() {
                        _items.insert(0, newItem);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Feedback submitted successfully!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isLight ? 0.06 : 0.10),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: isLight ? 0.18 : 0.16),
                  width: 1.0,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: TextStyle(
                  color: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary,
                  fontSize: 14.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Search feedback or ideas...',
                  hintStyle: TextStyle(
                    color: isLight
                        ? AppColors.lightTextTertiary
                        : AppColors.textTertiary,
                    fontSize: 14.0,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 12.0,
                  ),
                ),
              ),
            ),
          ),

          // 2. Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                _buildFilterChip('All', isLight),
                const SizedBox(width: 8.0),
                _buildFilterChip('Bug', isLight, label: '🪲 Bugs'),
                const SizedBox(width: 8.0),
                _buildFilterChip('Feature', isLight, label: '💡 Features'),
                const SizedBox(width: 8.0),
                _buildFilterChip('Improvement', isLight, label: '✨ Improvements'),
              ],
            ),
          ),

          const SizedBox(height: 4.0),

          // 3. Feedback Feed List
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState(isLight)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return FeedbackCard(
                        item: item,
                        onUpvote: () => _handleUpvote(item),
                        onDownvote: () => _handleDownvote(item),
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final updated = await Navigator.push<FeedbackItem>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FeedbackDetailsPage(
                                item: item,
                                onUpdate: (updatedItem) {
                                  final idx = _items.indexWhere(
                                      (i) => i.id == updatedItem.id);
                                  if (idx != -1) {
                                    setState(() {
                                      _items[idx] = updatedItem;
                                    });
                                  }
                                },
                              ),
                            ),
                          );
                          if (updated != null) {
                            final idx =
                                _items.indexWhere((i) => i.id == updated.id);
                            if (idx != -1) {
                              setState(() {
                                _items[idx] = updated;
                              });
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- SUB WIDGETS ---

  Widget _buildFilterChip(String filterKey, bool isLight, {String? label}) {
    final isSelected = _selectedFilter == filterKey;
    final displayLabel = label ?? filterKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedFilter = filterKey;
          });
        },
        borderRadius: BorderRadius.circular(20.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isLight ? Colors.white : const Color(0xFF161622)),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isLight
                      ? AppColors.borderLight
                      : Colors.white.withValues(alpha: 0.06)),
              width: 1.0,
            ),
          ),
          child: Text(
            displayLabel,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary),
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLight) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.primaryLight,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No feedback found',
              style: AppTextStyles.mdBold.copyWith(
                color: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Try changing your filter or search keywords.',
              textAlign: TextAlign.center,
              style: AppTextStyles.sm.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
