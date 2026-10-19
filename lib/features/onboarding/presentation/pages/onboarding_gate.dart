import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/pages/login_page.dart';
import '../../data/onboarding_storage.dart';
import 'onboarding_matching_page.dart';
import 'onboarding_page.dart';

/// What an unauthenticated user sees: the intro carousel on a first run, followed
/// by the genre matching screen, and the login screen every time after.
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
  bool _showMatching = false;

  @override
  void initState() {
    super.initState();
    _storage = OnboardingStorage(context.read<SharedPreferences>());
    _showOnboarding = !_storage.hasSeenOnboarding;
  }

  void _onCarouselFinished() {
    setState(() {
      _showOnboarding = false;
      _showMatching = true;
    });
  }

  void _onMatchingFinished() {
    _storage.markSeen();
    setState(() {
      _showMatching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingPage(onFinished: _onCarouselFinished);
    }
    if (_showMatching) {
      return OnboardingMatchingPage(onFinished: _onMatchingFinished);
    }
    return const LoginPage();
  }
}
