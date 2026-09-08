import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/poster_wall.dart';

/// Legacy alias pointing to [AppAssets.backdropPosters].
const List<String> loginWallPosterPaths = AppAssets.backdropPosters;

/// [PosterWall] preloaded with the backdrop poster set.
class LoginPosterWall extends StatelessWidget {
  const LoginPosterWall({super.key});

  @override
  Widget build(BuildContext context) =>
      const PosterWall(posterPaths: AppAssets.backdropPosters);
}
