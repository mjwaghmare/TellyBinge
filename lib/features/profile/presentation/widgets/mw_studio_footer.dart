import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Horizontally centered footer widget displayed at the bottom of the Settings page.
///
/// Features:
/// 1. "Crafted with 💜 by MWStudio" with interactive tap easter-egg.
/// 2. Outlined social & support icons: YouTube, Instagram, GitHub, and Buy Me a Coffee.
/// 3. Dynamic App Version & Copyright stamp.
class MWStudioFooter extends StatefulWidget {
  final String? appVersion;
  final String? buildNumber;

  const MWStudioFooter({super.key, this.appVersion, this.buildNumber});

  @override
  State<MWStudioFooter> createState() => _MWStudioFooterState();
}

class _MWStudioFooterState extends State<MWStudioFooter> {
  static const double _iconGlyphSize = 20.0;
  static const double _touchTargetSize = 40.0;

  late final ConfettiController _confettiController;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleEasterEggTap(BuildContext context) {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount < 5) {
      // Crisp tactile feedback on every tap of "Crafted with 💜 by MWStudio"
      HapticFeedback.lightImpact();
    } else {
      // Celebratory climax on 5th tap: heavy haptic punch, confetti blast & message
      _tapCount = 0;
      HapticFeedback.heavyImpact();
      _confettiController.stop();
      _confettiController.play();

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: '🎉 You found the creator secret! Crafted with 💜 by ${AppConstants.appCreator}',
          type: AppSnackbarType.info,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _launchSocialLink({
    required BuildContext context,
    required String webUrl,
    String? androidAppUrl,
    String? iosAppUrl,
  }) async {
    HapticFeedback.lightImpact();
    final bool isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final String? appUrl = isIos ? iosAppUrl : androidAppUrl;

    if (appUrl != null && appUrl.isNotEmpty) {
      final Uri appUri = Uri.parse(appUrl);
      try {
        if (await canLaunchUrl(appUri)) {
          final bool launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      } catch (_) {
        // Fall back to webUrl
      }
    }

    final Uri webUri = Uri.parse(webUrl);
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        AppSnackbar.showError(context, 'Could not open link.');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Could not open link.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = context.isLight;
    final Color iconColor = isLight ? AppColors.primary : AppColors.primaryLight;
    final Color labelColor = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final Color tertiaryColor = isLight ? AppColors.lightTextTertiary : AppColors.textTertiary;
    final versionStr = widget.appVersion ?? AppConstants.defaultAppVersion;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // CONFETTI CANNON (Smooth, floating celebratory burst in PopVerse brand colors)
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          emissionFrequency: 0.03,
          numberOfParticles: 16,
          gravity: 0.08,
          particleDrag: 0.05,
          maxBlastForce: 20,
          minBlastForce: 6,
          colors: const [
            AppColors.primary,
            AppColors.primaryLight,
            AppColors.primaryDark,
            AppColors.accentBlue,
            AppColors.brandGreen,
            Colors.amber,
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. BRANDING LINE WITH EASTER EGG TAP
              GestureDetector(
                onTap: () => _handleEasterEggTap(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Crafted with ', style: AppTextStyles.smMedium.copyWith(color: labelColor)),
                      const Text('💜', style: TextStyle(fontSize: 13)),
                      Text(
                        ' by ${AppConstants.appCreator}',
                        style: AppTextStyles.smMedium.copyWith(color: labelColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // 2. SOCIAL & SUPPORT OUTLINED ICONS ROW
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialIconButton(
                    tooltip: 'YouTube',
                    size: _iconGlyphSize,
                    touchSize: _touchTargetSize,
                    color: iconColor,
                    onTap: () => _launchSocialLink(
                      context: context,
                      webUrl: AppConstants.mwStudioYoutubeUrl,
                      androidAppUrl: AppConstants.mwStudioYoutubeAppScheme,
                      iosAppUrl: AppConstants.mwStudioYoutubeIosScheme,
                    ),
                    painter: _YouTubeOutlinePainter(color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SocialIconButton(
                    tooltip: 'Instagram',
                    size: _iconGlyphSize,
                    touchSize: _touchTargetSize,
                    color: iconColor,
                    onTap: () => _launchSocialLink(
                      context: context,
                      webUrl: AppConstants.mwStudioInstagramUrl,
                      androidAppUrl: AppConstants.mwStudioInstagramAppScheme,
                      iosAppUrl: AppConstants.mwStudioInstagramAppScheme,
                    ),
                    painter: _InstagramOutlinePainter(color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SocialIconButton(
                    tooltip: 'GitHub',
                    size: _iconGlyphSize,
                    touchSize: _touchTargetSize,
                    color: iconColor,
                    onTap: () => _launchSocialLink(
                      context: context,
                      webUrl: AppConstants.mwStudioGithubUrl,
                      androidAppUrl: AppConstants.mwStudioGithubAppScheme,
                      iosAppUrl: AppConstants.mwStudioGithubAppScheme,
                    ),
                    painter: _GitHubOutlinePainter(color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SocialIconButton(
                    tooltip: 'Buy Me a Coffee',
                    size: _iconGlyphSize,
                    touchSize: _touchTargetSize,
                    color: iconColor,
                    onTap: () => _launchSocialLink(context: context, webUrl: AppConstants.mwStudioBuyMeACoffeeUrl),
                    painter: _CoffeeOutlinePainter(color: iconColor),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // 3. APP VERSION & COPYRIGHT FOOTER
              Text(
                '${AppConstants.appName} v$versionStr • All rights reserved',
                style: AppTextStyles.xs.copyWith(color: tertiaryColor, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String tooltip;
  final double size;
  final double touchSize;
  final Color color;
  final VoidCallback onTap;
  final CustomPainter painter;

  const _SocialIconButton({
    required this.tooltip,
    required this.size,
    required this.touchSize,
    required this.color,
    required this.onTap,
    required this.painter,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: touchSize / 2,
          containedInkWell: false,
          highlightShape: BoxShape.circle,
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.1),
          child: SizedBox(
            width: touchSize,
            height: touchSize,
            child: Center(
              child: CustomPaint(size: Size(size, size), painter: painter),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// OUTLINE VECTOR PAINTERS (Zero Dependency)
// ==========================================

class _YouTubeOutlinePainter extends CustomPainter {
  final Color color;
  const _YouTubeOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer rounded rectangle
    final rect = Rect.fromLTWH(0.5, 2.5, size.width - 1.0, size.height - 5.0);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.22));
    canvas.drawRRect(rrect, strokePaint);

    // Centered play triangle
    final path = Path()
      ..moveTo(size.width * 0.40, size.height * 0.35)
      ..lineTo(size.width * 0.68, size.height * 0.50)
      ..lineTo(size.width * 0.40, size.height * 0.65)
      ..close();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _YouTubeOutlinePainter oldDelegate) => oldDelegate.color != color;
}

class _InstagramOutlinePainter extends CustomPainter {
  final Color color;
  const _InstagramOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer rounded square
    final rect = Rect.fromLTWH(1.0, 1.0, size.width - 2.0, size.height - 2.0);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.28));
    canvas.drawRRect(rrect, strokePaint);

    // Center lens circle
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.22, strokePaint);

    // Top right flash dot
    canvas.drawCircle(Offset(size.width * 0.73, size.height * 0.27), size.width * 0.055, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _InstagramOutlinePainter oldDelegate) => oldDelegate.color != color;
}

class _GitHubOutlinePainter extends CustomPainter {
  final Color color;
  const _GitHubOutlinePainter({required this.color});

  static Path? _cachedPath;

  static Path _getPath() {
    if (_cachedPath != null) return _cachedPath!;
    final path = Path();
    path.moveTo(12.0, 0.0);
    path.cubicTo(5.37, 0.0, 0.0, 5.37, 0.0, 12.0);
    path.cubicTo(0.0, 17.31, 3.435, 21.795, 8.205, 23.385);
    path.cubicTo(8.805, 23.49, 9.03, 23.13, 9.03, 22.815);
    path.cubicTo(9.03, 22.53, 9.015, 21.585, 9.015, 20.58);
    path.cubicTo(6.0, 21.135, 5.22, 19.845, 4.98, 19.17);
    path.cubicTo(4.845, 18.825, 4.26, 17.76, 3.75, 17.475);
    path.cubicTo(3.33, 17.25, 2.73, 16.695, 3.735, 16.68);
    path.cubicTo(4.68, 16.665, 5.355, 17.55, 5.58, 17.91);
    path.cubicTo(6.66, 19.725, 8.385, 19.215, 9.075, 18.9);
    path.cubicTo(9.18, 18.12, 9.495, 17.595, 9.84, 17.295);
    path.cubicTo(7.17, 16.995, 4.38, 15.96, 4.38, 11.37);
    path.cubicTo(4.38, 10.065, 4.845, 8.985, 5.61, 8.145);
    path.cubicTo(5.49, 7.845, 5.07, 6.615, 5.73, 4.965);
    path.cubicTo(5.73, 4.965, 6.735, 4.65, 9.03, 6.195);
    path.cubicTo(9.99, 5.925, 11.01, 5.79, 12.03, 5.79);
    path.cubicTo(13.05, 5.79, 14.07, 5.925, 15.03, 6.195);
    path.cubicTo(17.325, 4.635, 18.33, 4.965, 18.33, 4.965);
    path.cubicTo(18.99, 6.615, 18.57, 7.845, 18.45, 8.145);
    path.cubicTo(19.215, 8.985, 19.68, 10.05, 19.68, 11.37);
    path.cubicTo(19.68, 15.975, 16.875, 16.995, 14.205, 17.295);
    path.cubicTo(14.64, 17.67, 15.015, 18.39, 15.015, 19.515);
    path.cubicTo(15.015, 21.12, 15.0, 22.41, 15.0, 22.815);
    path.cubicTo(15.0, 23.13, 15.225, 23.505, 15.825, 23.385);
    path.arcToPoint(
      const Offset(24.0, 12.0),
      radius: const Radius.circular(12.0),
      rotation: 0.0,
      largeArc: false,
      clockwise: false,
    );
    path.cubicTo(24.0, 5.37, 18.63, 0.0, 12.0, 0.0);
    path.close();
    _cachedPath = path;
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);
    canvas.drawPath(_getPath(), fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GitHubOutlinePainter oldDelegate) => oldDelegate.color != color;
}

class _CoffeeOutlinePainter extends CustomPainter {
  final Color color;
  const _CoffeeOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scale = size.width / 20.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Cup body
    final cupPath = Path()
      ..moveTo(3.0, 5.5)
      ..lineTo(14.0, 5.5)
      ..lineTo(12.8, 14.0)
      ..arcToPoint(const Offset(4.2, 14.0), radius: const Radius.circular(2.5), clockwise: true)
      ..close();
    canvas.drawPath(cupPath, strokePaint);

    // Cup Handle
    final handlePath = Path()
      ..moveTo(13.8, 7.2)
      ..cubicTo(18.2, 7.2, 18.2, 12.2, 13.0, 12.2);
    canvas.drawPath(handlePath, strokePaint);

    // Saucer line
    canvas.drawLine(const Offset(2.8, 16.8), const Offset(14.2, 16.8), strokePaint);

    // Steam wisps above cup
    canvas.drawLine(const Offset(6.5, 3.2), const Offset(6.5, 1.6), strokePaint);
    canvas.drawLine(const Offset(10.5, 3.2), const Offset(10.5, 1.6), strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoffeeOutlinePainter oldDelegate) => oldDelegate.color != color;
}
