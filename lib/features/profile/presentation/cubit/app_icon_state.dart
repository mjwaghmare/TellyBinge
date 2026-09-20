import 'package:equatable/equatable.dart';
import '../../../../core/models/app_icon_option.dart';

class AppIconState extends Equatable {
  final AppIconOption currentIcon;
  final bool isApplying;
  final bool isSupported;
  final bool isProUser;
  final String? errorMessage;

  const AppIconState({
    this.currentIcon = AppIconOption.defaultIcon,
    this.isApplying = false,
    this.isSupported = true,
    this.isProUser = false,
    this.errorMessage,
  });

  AppIconState copyWith({
    AppIconOption? currentIcon,
    bool? isApplying,
    bool? isSupported,
    bool? isProUser,
    String? errorMessage,
  }) {
    return AppIconState(
      currentIcon: currentIcon ?? this.currentIcon,
      isApplying: isApplying ?? this.isApplying,
      isSupported: isSupported ?? this.isSupported,
      isProUser: isProUser ?? this.isProUser,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        currentIcon,
        isApplying,
        isSupported,
        isProUser,
        errorMessage,
      ];
}
