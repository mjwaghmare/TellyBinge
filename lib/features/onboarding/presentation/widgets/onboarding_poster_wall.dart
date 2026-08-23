import 'package:flutter/material.dart';

import '../../../../core/widgets/poster_wall.dart';

/// TMDb poster paths for the onboarding backdrop. Deliberately a different set
/// from the login wall, so the two screens don't look like the same picture
/// twice on a first run.
///
/// Hard-coded for the same reason as the login set: onboarding is the first
/// frame a new install paints, and a wall that fills in after a network
/// round-trip would spend that moment as a grid of empty boxes.
const List<String> onboardingWallPosterPaths = [
  '/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg', // Severance
  '/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg', // The Last of Us
  '/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg', // Breaking Bad
  '/zjg4jpK1Wp2kiRvtt5ND0kznako.jpg', // Better Call Saul
  '/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg', // Stranger Things
  '/9PFonBhy4cQy7Jz20NpMygczOkv.jpg', // Wednesday
  '/in1R2dDc421JxsoRWaIIAqVI2KE.jpg', // The Boys
  '/7DJKHzAi83BmQrWLrYYOqcoKfhR.jpg', // The Office
  '/u68AjlvlutfEIcpmbYpKcdi09ut.jpg', // Everything Everywhere All at Once
  '/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg', // Barbie
  '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', // Parasite
  '/7fn624j5lj3xTme2SgiLCeuedmO.jpg', // Whiplash
  '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', // The Godfather
  '/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg', // Fight Club
  '/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg', // La La Land
  '/wN2xWp1eIwCKOD0BHTcErTBv1Uq.jpg', // Gladiator
];

/// [PosterWall] preloaded with the onboarding carousel's poster set.
class OnboardingPosterWall extends StatelessWidget {
  const OnboardingPosterWall({super.key});

  @override
  Widget build(BuildContext context) =>
      const PosterWall(posterPaths: onboardingWallPosterPaths);
}
