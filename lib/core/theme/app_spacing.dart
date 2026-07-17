import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
  static const double huge = 64.0;

  // Edge Insets helper utilities
  static const EdgeInsets allXXS = EdgeInsets.all(xxs);
  static const EdgeInsets allXS = EdgeInsets.all(xs);
  static const EdgeInsets allSM = EdgeInsets.all(sm);
  static const EdgeInsets allMD = EdgeInsets.all(md);
  static const EdgeInsets allLG = EdgeInsets.all(lg);
  static const EdgeInsets allXL = EdgeInsets.all(xl);

  // Horizontal spacing widgets
  static const SizedBox gapW4 = SizedBox(width: xxs);
  static const SizedBox gapW8 = SizedBox(width: xs);
  static const SizedBox gapW12 = SizedBox(width: sm);
  static const SizedBox gapW16 = SizedBox(width: md);
  static const SizedBox gapW20 = SizedBox(width: lg);
  static const SizedBox gapW24 = SizedBox(width: xl);
  static const SizedBox gapW32 = SizedBox(width: xxl);

  // Vertical spacing widgets
  static const SizedBox gapH4 = SizedBox(height: xxs);
  static const SizedBox gapH8 = SizedBox(height: xs);
  static const SizedBox gapH12 = SizedBox(height: sm);
  static const SizedBox gapH16 = SizedBox(height: md);
  static const SizedBox gapH20 = SizedBox(height: lg);
  static const SizedBox gapH24 = SizedBox(height: xl);
  static const SizedBox gapH32 = SizedBox(height: xxl);
  static const SizedBox gapH48 = SizedBox(height: xxxl);
}
