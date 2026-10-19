import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/pages/login_page.dart';
import '../../data/onboarding_storage.dart';
import 'onboarding_page.dart';

/// What an unauthenticated user sees: the 5-slide intro carousel (including genre matching)
/// on a first run, and the login screen every time after.
///
/// The flag is read synchronously from the already-loaded [SharedPreferences]
/// instance, so a returning user never sees a frame of onboarding before it
/// resolves.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final OnboardingStorage _storage;
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _storage = OnboardingStorage(context.read<SharedPreferences>());
    _showOnboarding = !_storage.hasSeenOnboarding;
  }

  void _onOnboardingFinished() {
    _storage.markSeen();
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingPage(onFinished: _onOnboardingFinished);
    }
    return const LoginPage();
  }
}
