import 'package:flutter/material.dart';

import '../../../../core/widgets/poster_wall.dart';
import '../../../auth/presentation/widgets/login_poster_wall.dart';

/// [PosterWall] preloaded with the login screen's poster set for onboarding.
class OnboardingPosterWall extends StatelessWidget {
  const OnboardingPosterWall({super.key});

  @override
  Widget build(BuildContext context) =>
      const PosterWall(posterPaths: loginWallPosterPaths);
}

