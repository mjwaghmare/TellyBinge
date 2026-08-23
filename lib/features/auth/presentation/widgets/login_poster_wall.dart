import 'package:flutter/material.dart';

import '../../../../core/widgets/poster_wall.dart';

/// TMDb poster paths for the login backdrop — the fan-favourite series the app
/// was built around, mixed with well-known films so the wall reads as
/// "TV *and* movies" at a glance.
///
/// Hard-coded rather than pulled from TMDb: the login screen is the very first
/// thing an unauthenticated user sees, and a wall that only fills in once a
/// network call lands would spend that moment as a grid of empty boxes.
const List<String> loginWallPosterPaths = [
  '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', // Game of Thrones
  '/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg', // Friends
  '/yZevl2vHQgmosfwUdVNzviIfaWS.jpg', // The Flash
  '/u8ZHFj1jC384JEkTt3vNg1DfWEb.jpg', // Arrow
  '/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg', // Inception
  '/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg', // Interstellar
  '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', // The Dark Knight
  '/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg', // Avengers: Infinity War
  '/v1tRXZ4JtD2Iv6fjkPvT4GiwslV.jpg', // Dune
  '/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg', // Spider-Man: No Way Home
  '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', // Oppenheimer
  '/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg', // Joker
  '/n0YuM4f5lvGAP6MAW2kBIzugXnc.jpg', // Top Gun: Maverick
  '/dXNAPwY7VrqMAo51EKhhCJfaGb5.jpg', // The Matrix
];

/// [PosterWall] preloaded with the login screen's poster set.
class LoginPosterWall extends StatelessWidget {
  const LoginPosterWall({super.key});

  @override
  Widget build(BuildContext context) =>
      const PosterWall(posterPaths: loginWallPosterPaths);
}
