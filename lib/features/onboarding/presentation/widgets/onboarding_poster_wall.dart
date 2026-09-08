import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/poster_wall.dart';

/// [PosterWall] preloaded with the backdrop poster set for onboarding.
class OnboardingPosterWall extends StatelessWidget {
  const OnboardingPosterWall({super.key});

  @override
  Widget build(BuildContext context) =>
      const PosterWall(posterPaths: AppAssets.backdropPosters);
}
