import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standalone, industry-standard Terms & Conditions page.
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final backgroundColor = isLight ? AppColors.lightBackground : AppColors.background;
    final surfaceColor = isLight ? AppColors.lightSurface : AppColors.surface;
    final borderColor = isLight ? AppColors.borderLight : AppColors.borderDark;
    final primaryTextColor = isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final secondaryTextColor = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Terms & Conditions',
          style: AppTextStyles.lg.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 20),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          // Header Card with Badge
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'Legal Agreement',
                    style: AppTextStyles.xsBold.copyWith(color: AppColors.primary),
                  ),
                ),
                AppSpacing.gapH12,
                Text(
                  'PopVerse Terms of Service',
                  style: AppTextStyles.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                AppSpacing.gapH4,
                Text(
                  'Effective Date: September 2026',
                  style: AppTextStyles.xs.copyWith(color: secondaryTextColor),
                ),
                AppSpacing.gapH12,
                Text(
                  'Please read these Terms & Conditions ("Terms") carefully before using the PopVerse mobile application or website ("Service"). By accessing or using PopVerse, you agree to be bound by these Terms.',
                  style: AppTextStyles.sm.copyWith(
                    color: secondaryTextColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapH16,

          // Crucial Disclaimer Callout Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                AppSpacing.gapW12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No-Streaming & Information Utility Notice',
                        style: AppTextStyles.smBold.copyWith(color: AppColors.primary),
                      ),
                      AppSpacing.gapH4,
                      Text(
                        'PopVerse is an entertainment discovery and tracking utility. PopVerse DOES NOT host, stream, upload, or broadcast any movies, TV episodes, or unauthorized videos. Any trailers or video clips are embedded via official third-party APIs (e.g., YouTube) in compliance with their terms.',
                        style: AppTextStyles.xs.copyWith(
                          color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapH16,

          // Structured Legal Sections
          _buildLegalSection(
            number: '1',
            title: 'Acceptance of Terms & Eligibility',
            content:
                'By accessing or using PopVerse, you confirm that you are at least 13 years of age (or the minimum legal age required in your jurisdiction) and possess the legal capacity to enter into these Terms. If you are under the age of majority, you may only use PopVerse with parental or guardian consent. If you do not agree to these Terms, you must discontinue using PopVerse immediately.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '2',
            title: 'Nature of Service',
            content:
                'PopVerse provides personalized tools to track watched shows and movies, organize watchlists, receive release notifications, calculate watch statistics, and discover entertainment recommendations. PopVerse is solely an informational tracker and is not a video-on-demand or media distribution platform.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '3',
            title: 'Intellectual Property & TMDb Attribution',
            content:
                '• TMDb Attribution: PopVerse uses metadata, episode information, cast details, and poster artwork provided by The Movie Database (TMDb) API. PopVerse is not endorsed, certified, or sponsored by TMDb.\n\n• Studio Rights: All movie and television titles, artwork, character names, and promotional materials remain the intellectual property and copyright of their respective studios, networks, and production companies.\n\n• PopVerse IP: The PopVerse name, logo, custom UI design, animations, source code, and original graphics are the exclusive property of PopVerse. Unauthorized copying, modification, or redistribution is strictly prohibited.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '4',
            title: 'User Accounts & Responsibilities',
            content:
                'You may explore PopVerse in Guest Mode or authenticate using third-party providers (e.g., Google Sign-In). If you create an account, you are responsible for maintaining the confidentiality of your credentials and for all actions taken under your account. You agree not to impersonate others, attempt unauthorized access to our servers, or use bots, scrapers, or automated tools on the platform.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '5',
            title: 'User-Generated Content & Conduct',
            content:
                'PopVerse enables users to submit feedback, bug reports, feature suggestions, comments, and upvotes. You grant PopVerse a worldwide, non-exclusive, royalty-free license to display and store your submissions. You agree NOT to post content that:\n• Is defamatory, abusive, harassing, threatening, or sexually explicit.\n• Infringes any third party’s intellectual property or privacy rights.\n• Contains commercial advertisements, spam, or malicious software.\n\nPopVerse reserves the right to moderate, hide, or delete any content that violates these guidelines without notice.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '6',
            title: 'Notifications & Device Permissions',
            content:
                'PopVerse offers episode airdate reminders, release countdowns, and service alerts via local and push notifications. You can toggle or customize notification permissions at any time through your device system settings or in-app preferences.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '7',
            title: 'Third-Party Services & Links',
            content:
                'Our Service integrates with trusted third-party providers including Google Sign-In, Firebase (Authentication & Firestore), Cloudinary, TMDb, and YouTube. PopVerse does not control and is not liable for third-party privacy policies, terms, or service availability.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '8',
            title: 'Disclaimer of Warranties',
            content:
                'PopVerse is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, whether express or implied. We do not guarantee that release schedules, air dates, or metadata will always be accurate, complete, or uninterrupted. Television broadcast schedules and streaming platform licenses are subject to change by third parties without notice.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '9',
            title: 'Limitation of Liability',
            content:
                'To the maximum extent permitted by applicable law, PopVerse, its creators, and affiliates shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of or inability to access the Service.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '10',
            title: 'Modifications & Termination',
            content:
                'We reserve the right to revise these Terms periodically. Continued use of PopVerse following published changes constitutes your acceptance of the updated Terms. We may suspend or terminate accounts that breach these Terms or compromise community security.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          _buildLegalSection(
            number: '11',
            title: 'Contact & Legal Notices',
            content:
                'If you have any questions, feedback, or legal inquiries regarding these Terms & Conditions, please contact us at:\n\nEmail: ${AppConstants.supportEmail}',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          AppSpacing.gapH24,
        ],
      ),
    );
  }

  Widget _buildLegalSection({
    required String number,
    required String title,
    required String content,
    required Color surfaceColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: AppTextStyles.xsBold.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              AppSpacing.gapW8,
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.mdBold.copyWith(color: primaryTextColor),
                ),
              ),
            ],
          ),
          AppSpacing.gapH12,
          Text(
            content,
            style: AppTextStyles.sm.copyWith(
              color: secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
