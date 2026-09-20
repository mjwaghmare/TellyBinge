import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/app_icon_option.dart';
import '../../../../core/services/app_icon_service.dart';
import 'app_icon_state.dart';

class AppIconCubit extends Cubit<AppIconState> {
  final AppIconService _service;

  AppIconCubit({
    AppIconService? service,
    bool isProUser = false,
  })  : _service = service ?? AppIconService(),
        super(AppIconState(isProUser: isProUser)) {
    _initialize();
  }

  Future<void> _initialize() async {
    final isSupported = await _service.supportsAlternateIcons;
    if (isClosed) return;

    final current = await _service.getCurrentIcon();
    if (isClosed) return;

    emit(state.copyWith(
      currentIcon: current,
      isSupported: isSupported,
    ));
  }

  Future<bool> selectIcon(AppIconOption option) async {
    if (state.isApplying) return false;
    if (option == state.currentIcon) return true;

    // Enforce entitlement check for premium icons
    if (option.isPremium && !state.isProUser) {
      emit(state.copyWith(
        errorMessage: 'This icon is reserved for Popverse Pro users.',
      ));
      return false;
    }

    emit(state.copyWith(isApplying: true, errorMessage: null));

    final success = await _service.setAppIcon(option);
    if (isClosed) return false;

    if (success) {
      emit(state.copyWith(
        currentIcon: option,
        isApplying: false,
      ));
      return true;
    } else {
      emit(state.copyWith(
        isApplying: false,
        errorMessage: 'Unable to update app icon on this device.',
      ));
      return false;
    }
  }
}
