import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standalone, industry-standard Privacy Policy page.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
          'Privacy Policy',
          style: AppTextStyles.lg.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
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
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'Privacy & Data Protection',
                    style: AppTextStyles.xsBold.copyWith(color: AppColors.success),
                  ),
                ),
                AppSpacing.gapH12,
                Text(
                  'PopVerse Privacy Policy',
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
                  'PopVerse respects your privacy and is committed to protecting your personal data. This Privacy Policy explains what data we collect, why we collect it, how it is secured, and your legal rights under GDPR, CCPA/CPRA, and relevant privacy frameworks.',
                  style: AppTextStyles.sm.copyWith(
                    color: secondaryTextColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapH16,

          // Core Privacy Commitment Highlight
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 22),
                AppSpacing.gapW12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Our Core Privacy Principles',
                        style: AppTextStyles.smBold.copyWith(color: AppColors.success),
                      ),
                      AppSpacing.gapH4,
                      Text(
                        '• We DO NOT sell, rent, or monetize your personal data.\n• We DO NOT track you across third-party websites or apps.\n• Your watchlists, history, and library items belong entirely to you.',
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

          // Section 1: Information We Collect
          _buildLegalSection(
            number: '1',
            title: 'Information We Collect',
            content:
                'We collect minimal information necessary to deliver and personalize your experience:\n\n'
                '• Account & Identity: When you sign in (e.g., via Google Sign-In or Firebase), we store your unique User ID (UID), email address, display name, and avatar URL.\n\n'
                '• Watchlist & Library Data: Movies and TV shows you save, mark as watched, episode progress, ratings, and watch streak metrics.\n\n'
                '• User Feedback & Submissions: Bug reports, feedback messages, community comments, votes, and user-uploaded screenshots.\n\n'
                '• Technical & Device Diagnostics: App version, operating system (iOS or Android), and anonymous error logs to resolve crashes.\n\n'
                '• What We Never Collect: We never collect payment card details, national IDs, biometric scans, or continuous GPS location.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 2: How We Use Your Information
          _buildLegalSection(
            number: '2',
            title: 'How We Use Your Information',
            content:
                'Your information is used strictly to provide, maintain, and enhance the Service:\n\n'
                '• Cloud Synchronization: Syncing your watch history, watchlist, and ratings securely across your devices.\n\n'
                '• Release Alerts: Sending timely reminders when new episodes air or movies premiere.\n\n'
                '• Viewing Insights: Computing your watch hours, streak records, and personalized genre statistics.\n\n'
                '• App Reliability: Identifying performance bottlenecks, resolving app crashes, and investigating bug reports.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 3: Third-Party Service Providers
          _buildLegalSection(
            number: '3',
            title: 'Third-Party Services & Infrastructure',
            content:
                'We collaborate with trusted industry providers to operate our platform:\n\n'
                '• Google Firebase (Authentication & Cloud Firestore): Manages secure user authentication, real-time database storage, and encryption.\n\n'
                '• The Movie Database (TMDb): Powers media search, descriptions, cast listings, and posters via public APIs.\n\n'
                '• Cloudinary: Provides secure, encrypted cloud hosting for user-submitted feedback images.\n\n'
                '• YouTube API Services: Enables in-app streaming of official movie and TV trailers.\n\n'
                '• Web3Forms: Transmits automated admin alerts for user-submitted feedback.\n\n'
                'All third-party partners are vetted to comply with international data security and privacy standards.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 4: Data Security & Storage
          _buildLegalSection(
            number: '4',
            title: 'Data Security & Encryption',
            content:
                'We enforce strict technical and organizational safeguards to protect your data:\n\n'
                '• Encryption in Transit: All network communications use modern TLS/SSL (HTTPS) encryption protocols.\n\n'
                '• Encryption at Rest: User records and watchlists are stored with AES-256 encryption in Google Cloud Firestore.\n\n'
                '• Access Controls: Granular Firestore security rules restrict write and read access so only you can access and modify your private library.\n\n'
                '• Secure Media: Uploaded images are routed via unsigned, restricted upload presets without exposing private backend credentials on client devices.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 5: Data Retention & Account Deletion
          _buildLegalSection(
            number: '5',
            title: 'Data Retention & Deletion Rights',
            content:
                'We retain your personal data only as long as your account remains active. You maintain full ownership and control of your data:\n\n'
                '• Export Your Data: You can export your watchlist and watch history to CSV format at any time using the in-app export feature.\n\n'
                '• Account Deletion: You can permanently delete your account and all associated Firestore records (watch history, lists, ratings) directly from the Settings page or by contacting ${AppConstants.supportEmail}. Deletion is irrevocable and permanently purges your data.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 6: User Privacy Rights (GDPR & CCPA/CPRA)
          _buildLegalSection(
            number: '6',
            title: 'Your Privacy Rights (GDPR & CCPA)',
            content:
                'Depending on your location, you hold statutory rights regarding your personal information:\n\n'
                '• Right to Access: Request a copy of the personal information we hold about you.\n'
                '• Right to Rectification: Correct inaccurate or incomplete account information.\n'
                '• Right to Erasure: Request complete deletion of your data.\n'
                '• Right to Data Portability: Receive your data in a structured, machine-readable format.\n'
                '• Right to Object / Restrict: Opt out of non-essential communications or data processing.\n\n'
                'To exercise any of these rights, simply email ${AppConstants.supportEmail}. We respond to all verified requests within 30 days without charge.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 7: Children's Privacy (COPPA)
          _buildLegalSection(
            number: '7',
            title: "Children's Privacy Protection",
            content:
                'PopVerse is not targeted toward or designed for children under 13 years of age (or under 16 in the EEA). We do not knowingly collect personal data from minors. If you believe that a child has provided us with personal information without parental consent, please contact us immediately, and we will promptly remove the information from our servers.',
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          // Section 8: Policy Updates & Contact
          _buildLegalSection(
            number: '8',
            title: 'Policy Updates & Contact Information',
            content:
                'We may update this Privacy Policy periodically to reflect new product features or statutory regulations. Any revisions will be published with an updated "Effective Date" at the top of this page.\n\n'
                'If you have questions, concerns, or requests regarding this Privacy Policy, please contact our Data Protection team:\n\n'
                'Email: ${AppConstants.supportEmail}',
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
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: AppTextStyles.xsBold.copyWith(color: AppColors.success),
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
