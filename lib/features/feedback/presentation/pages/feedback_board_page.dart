import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../data/repositories/feedback_repository_impl.dart';
import '../widgets/feedback_card.dart';
import '../widgets/submit_feedback_sheet.dart';
import 'feedback_details_page.dart';

class FeedbackBoardPage extends StatefulWidget {
  final FeedbackRepository? feedbackRepository;

  const FeedbackBoardPage({super.key, this.feedbackRepository});

  @override
  State<FeedbackBoardPage> createState() => _FeedbackBoardPageState();
}

class _FeedbackBoardPageState extends State<FeedbackBoardPage> {
  late final FeedbackRepository _repository;
  StreamSubscription<List<FeedbackItem>>? _subscription;
  List<FeedbackItem> _items = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _currentUserId = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.feedbackRepository ?? FeedbackRepositoryImpl();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _subscribeToFeedbacks();
  }

  void _subscribeToFeedbacks() {
    _subscription?.cancel();

    // Fallback timeout to guarantee UI renders empty state without hanging
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    _subscription = _repository
        .getFeedbacksStream(currentUserId: _currentUserId)
        .listen(
          (items) {
            if (mounted) {
              setState(() {
                _items = items;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            debugPrint('FeedbackBoardPage: Error in feedback stream: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
        final matchesSearch =
            _searchQuery.isEmpty ||
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
      _items[index] = _items[index].upvoted(_currentUserId);
    });

    if (_currentUserId.isNotEmpty) {
      _repository.toggleVote(
        feedbackId: item.id,
        userId: _currentUserId,
        isUpvote: true,
      );
    }
  }

  void _handleDownvote(FeedbackItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    setState(() {
      _items[index] = _items[index].downvoted(_currentUserId);
    });

    if (_currentUserId.isNotEmpty) {
      _repository.toggleVote(
        feedbackId: item.id,
        userId: _currentUserId,
        isUpvote: false,
      );
    }
  }

  void _openSubmitSheet() {
    HapticFeedback.lightImpact();
    SubmitFeedbackSheet.show(
      context,
      feedbackRepository: _repository,
      onSubmit: (newItem) {
        AppSnackbar.showSuccess(
          context,
          'Feedback submitted successfully!',
          duration: const Duration(seconds: 2),
        );
      },
    );
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
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Feedback & Requests',
          style: AppTextStyles.lg.copyWith(
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
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
                onPressed: _openSubmitSheet,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Column(
              children: [
                // 1. Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: isLight ? 0.06 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: AppColors.primary.withValues(
                          alpha: isLight ? 0.18 : 0.16,
                        ),
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
                      _buildFilterChip(
                        'Feature',
                        isLight,
                        label: '💡 Features',
                      ),
                      const SizedBox(width: 8.0),
                      _buildFilterChip(
                        'Improvement',
                        isLight,
                        label: '✨ Improvements',
                      ),
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
                                final updated =
                                    await Navigator.push<FeedbackItem>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FeedbackDetailsPage(
                                          item: item,
                                          feedbackRepository: _repository,
                                        ),
                                      ),
                                    );
                                if (updated != null) {
                                  final idx = _items.indexWhere(
                                    (i) => i.id == updated.id,
                                  );
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
    final isBoardEmpty = _items.isEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isLight ? 0.1 : 0.15,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(
                    alpha: isLight ? 0.2 : 0.25,
                  ),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isBoardEmpty
                    ? Icons.mark_chat_unread_outlined
                    : Icons.search_off_rounded,
                color: AppColors.primaryLight,
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isBoardEmpty ? 'No feedback yet' : 'No matching feedback',
              style: AppTextStyles.mdBold.copyWith(
                color: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isBoardEmpty
                  ? 'Be the first to share an idea, report an issue, or suggest improvements!'
                  : 'Try adjusting your search query or selecting a different category filter.',
              textAlign: TextAlign.center,
              style: AppTextStyles.sm.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isBoardEmpty)
              ElevatedButton.icon(
                onPressed: _openSubmitSheet,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Submit Feedback',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedFilter = 'All';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
