import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../auth/presentation/widgets/auth_required_view.dart';
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
  StreamSubscription<User?>? _authSubscription;
  List<FeedbackItem> _items = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _currentUserId = '';
  final Set<String> _pendingVoteIds = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.feedbackRepository ?? FeedbackRepositoryImpl();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (_currentUserId.isNotEmpty) {
      _subscribeToFeedbacks();
    } else {
      _isLoading = false;
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final newUid = user?.uid ?? '';
      if (newUid != _currentUserId) {
        setState(() {
          _currentUserId = newUid;
          _isLoading = newUid.isNotEmpty;
        });
        if (newUid.isNotEmpty) {
          _subscribeToFeedbacks();
        } else {
          _subscription?.cancel();
          setState(() {
            _items = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  void _subscribeToFeedbacks([Completer<void>? refreshCompleter]) {
    _subscription?.cancel();

    // Fallback timeout to guarantee UI renders empty state without hanging
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      if (refreshCompleter != null && !refreshCompleter.isCompleted) {
        refreshCompleter.complete();
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
            if (refreshCompleter != null && !refreshCompleter.isCompleted) {
              refreshCompleter.complete();
            }
          },
          onError: (error) {
            debugPrint('FeedbackBoardPage: Error in feedback stream: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            if (refreshCompleter != null && !refreshCompleter.isCompleted) {
              refreshCompleter.complete();
            }
          },
        );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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

  Future<void> _handleUpvote(FeedbackItem item) async {
    if (_currentUserId.isEmpty) {
      AppSnackbar.showInfo(
        context,
        'Please sign in to vote on feedback.',
      );
      return;
    }

    if (item.userId == _currentUserId && item.isUpvoted) {
      unawaited(AppHaptics.lightImpact());
      AppSnackbar.showInfo(
        context,
        'You created this feedback — your upvote is permanent.',
      );
      return;
    }

    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1 || _pendingVoteIds.contains(item.id)) return;

    unawaited(AppHaptics.mediumImpact());
    setState(() {
      _pendingVoteIds.add(item.id);
      _items[index] = _items[index].upvoted(_currentUserId);
    });

    try {
      await _repository.toggleVote(
        feedbackId: item.id,
        userId: _currentUserId,
      );
    } catch (_) {
      if (mounted) {
        final currentIndex = _items.indexWhere((entry) => entry.id == item.id);
        setState(() {
          if (currentIndex != -1) _items[currentIndex] = item;
          _pendingVoteIds.remove(item.id);
        });
        AppSnackbar.showError(context, 'Failed to update your vote. Please try again.');
      }
      return;
    }

    if (mounted) setState(() => _pendingVoteIds.remove(item.id));
  }

  void _openSubmitSheet() {
    AppHaptics.lightImpact();
    if (FirebaseAuth.instance.currentUser == null) {
      AuthRequiredBottomSheet.show(
        context,
        title: 'Sign in to share feedback',
        subtitle: 'Use your account to submit ideas, bugs, and improvements.',
        icon: Icons.feedback_outlined,
      );
      return;
    }
    SubmitFeedbackSheet.show(
      context,
      feedbackRepository: _repository,
      existingItems: _items,
      onSubmit: (newItem) {
        AppSnackbar.showSuccess(
          context,
          'Feedback submitted successfully!',
          duration: const Duration(seconds: 2),
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    unawaited(AppHaptics.lightImpact());
    final completer = Completer<void>();
    _subscribeToFeedbacks(completer);

    await Future.any([
      completer.future,
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    if (_currentUserId.isEmpty) {
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
        ),
        body: const AuthRequiredView(
          icon: Icons.rate_review_outlined,
          badge: 'Community',
          title: 'Community Feedback',
          subtitle:
              'Sign in to explore community suggestions, report bugs, and vote on what gets built next.',
          features: [
            'Vote on feature requests and ideas',
            'Submit bugs with screenshot attachments',
            'Join discussions with the community',
          ],
        ),
      );
    }

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
            padding: const EdgeInsets.only(right: AppSpacing.sm),
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
                  color: AppColors.textOnPrimary,
                  size: 24,
                ),
                onPressed: _openSubmitSheet,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _isLoading && _items.isEmpty
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
                        color: isLight
                            ? AppColors.lightSurface
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(
                          color: isLight
                              ? AppColors.borderLight
                              : AppColors.borderDark,
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
                        style: AppTextStyles.sm.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search feedback or ideas...',
                          hintStyle: AppTextStyles.sm.copyWith(
                            color: isLight
                                ? AppColors.lightTextTertiary
                                : AppColors.textTertiary,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isLight
                                ? AppColors.lightTextTertiary
                                : AppColors.textTertiary,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: isLight
                                        ? AppColors.lightTextTertiary
                                        : AppColors.textTertiary,
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
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                  ),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip('All', isLight),
                          AppSpacing.gapW8,
                          _buildFilterChip('Bug', isLight, label: '🪲 Bugs'),
                          AppSpacing.gapW8,
                          _buildFilterChip(
                            'Feature',
                            isLight,
                            label: '💡 Features',
                          ),
                          AppSpacing.gapW8,
                          _buildFilterChip(
                            'Improvement',
                            isLight,
                            label: '✨ Improvements',
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.gapH4,

                  // 3. Feedback Feed List with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator.adaptive(
                      onRefresh: _handleRefresh,
                      color: AppColors.primary,
                      child: items.isEmpty
                          ? _buildEmptyState(isLight)
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return FeedbackCard(
                                  item: item,
                                  isVotePending: _pendingVoteIds.contains(item.id),
                                  onUpvote: () => _handleUpvote(item),
                                  onTap: () async {
                                    unawaited(AppHaptics.lightImpact());
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
                  ),
                ],
              ),
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
          AppHaptics.lightImpact();
          setState(() {
            _selectedFilter = filterKey;
          });
        },
        borderRadius: BorderRadius.circular(20.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isLight ? AppColors.lightSurface : AppColors.surface),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isLight
                        ? AppColors.borderLight
                        : AppColors.borderDark),
              width: 1.0,
            ),
          ),
          child: Text(
            displayLabel,
            style: AppTextStyles.smMedium.copyWith(
              color: isSelected
                  ? AppColors.textOnPrimary
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
    final isFiltering = _selectedFilter != 'All' || _searchQuery.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: isFiltering
            ? AppEmptyState(
                icon: Icons.search_off_rounded,
                title: _searchQuery.isNotEmpty
                    ? 'No Matching Feedback'
                    : 'No $_selectedFilter Feedback Yet',
                body: _searchQuery.isNotEmpty
                    ? 'Try adjusting your search terms or filter.'
                    : 'There is no feedback in this category yet.',
                primaryLabel: 'CLEAR FILTERS',
                onPrimary: () {
                  setState(() {
                    _selectedFilter = 'All';
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                compact: true,
              )
            : AppEmptyState(
                icon: Icons.mark_chat_unread_outlined,
                title: 'No Feedback Yet',
                body:
                    'Be the first to share an idea, report an issue, or suggest improvements!',
                primaryLabel: 'SUBMIT FEEDBACK',
                onPrimary: _openSubmitSheet,
                compact: true,
              ),
      ),
    );
  }
}
