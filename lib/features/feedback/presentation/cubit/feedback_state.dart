import 'package:equatable/equatable.dart';
import '../../domain/models/feedback_item.dart';

abstract class FeedbackState extends Equatable {
  const FeedbackState();

  @override
  List<Object?> get props => [];
}

class FeedbackInitial extends FeedbackState {}

class FeedbackLoading extends FeedbackState {}

class FeedbackLoaded extends FeedbackState {
  final List<FeedbackItem> items;
  final bool isSubmitting;
  final String? submitError;

  const FeedbackLoaded({
    required this.items,
    this.isSubmitting = false,
    this.submitError,
  });

  FeedbackLoaded copyWith({
    List<FeedbackItem>? items,
    bool? isSubmitting,
    String? submitError,
  }) {
    return FeedbackLoaded(
      items: items ?? this.items,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
    );
  }

  @override
  List<Object?> get props => [items, isSubmitting, submitError];
}

class FeedbackError extends FeedbackState {
  final String message;

  const FeedbackError(this.message);

  @override
  List<Object?> get props => [message];
}
