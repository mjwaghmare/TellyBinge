# TellyBinge Design System

This document outlines the core visual language, design tokens, typography, spacing scale, component patterns, and UI rules for the **TellyBinge** mobile application.

---

## 1. 🎨 Color Palette & Theme Tokens

All color references in the application **must** consume `AppColors` tokens defined in [`lib/core/theme/app_colors.dart`](file:///Users/admin/Documents/mwstudioprojects/tvtimeapp/lib/core/theme/app_colors.dart) or semantic properties from `Theme.of(context)`. Direct raw hex colors in widgets are strictly prohibited.

### Brand Colors
| Token Name | Hex Value | Preview | Usage |
| :--- | :--- | :--- | :--- |
| `AppColors.primary` | `#FFC107` | 🟡 Amber | Primary buttons, active tab indicators, key accents |
| `AppColors.primaryDark` | `#FF8F00` | 🟠 Dark Amber | Pressed states, secondary brand accents |
| `AppColors.primaryLight` | `#FFD54F` | 💛 Light Amber | Highlights, badge background accents |

### Accent & Status Tokens
| Token Name | Hex Value | Usage |
| :--- | :--- | :--- |
| `AppColors.brandGreen` | `#6B8E23` | TV Time green watch progress badges & checkmarks |
| `AppColors.accentBlue` | `#1E88E5` | Placeholder media icons & secondary action accents |
| `AppColors.watched` | `#FFC107` | Watch progress bar fill |
| `AppColors.airing` | `#2196F3` | Airing status tags for TV shows |
| `AppColors.ended` | `#9C27B0` | Ended status tags for TV shows |
| `AppColors.error` | `#E53935` | Destructive buttons, error alerts, removing items |
| `AppColors.success` | `#4CAF50` | Positive confirmations |

### Dark & Light Surface Tokens
| Token Name | Hex Value | Usage |
| :--- | :--- | :--- |
| `AppColors.darkBackground` / `background` | `#0D0D0D` | Solid dark scaffold background |
| `AppColors.surface` | `#161616` | Standard card background |
| `AppColors.surfaceLight` | `#222222` | Text fields, list tile backgrounds |
| `AppColors.surfaceDarkAlt` | `#1E1E1E` | Bottom sheet backgrounds, modal cards |
| `AppColors.surfaceElevated` | `#2C2C2E` | Elevated chip fills, modal tiles |
| `AppColors.borderLight` | `#CCCCCC` | Light mode borders and inactive filter outlines |

### Text Color Tokens
| Token Name | Hex Value | Usage |
| :--- | :--- | :--- |
| `AppColors.textPrimary` | `#FFFFFF` | Primary body text and headers in dark mode |
| `AppColors.textSecondary` | `#B0B0B0` | Subtitles, metadata, secondary text |
| `AppColors.textTertiary` | `#757575` | Inactive icons, subtle text, placeholder hints |
| `AppColors.textOnPrimary` | `#000000` | Text rendered on top of `AppColors.primary` |

---

## 2. 🔤 Typography System

Typography is driven globally by **Google Fonts Nunito** and system fallback via `AppTextStyles` in [`lib/core/theme/app_text_styles.dart`](file:///Users/admin/Documents/mwstudioprojects/tvtimeapp/lib/core/theme/app_text_styles.dart).

| Style Token | Font Size | Weight | Line Height / Case | Common Usage |
| :--- | :--- | :--- | :--- | :--- |
| `AppTextStyles.xs` | 12.0pt | Normal | Regular | Timestamps, small metadata badges |
| `AppTextStyles.xsMedium` | 12.0pt | Medium (w500) | Regular | Bottom nav labels, tags |
| `AppTextStyles.sm` | 14.0pt | Normal | Regular | Body text, list descriptions |
| `AppTextStyles.smMedium` | 14.0pt | Medium (w500) | Regular | Subtitles, input field values |
| `AppTextStyles.smBold` | 14.0pt | Bold (w700) | Regular | Button text, chip labels |
| `AppTextStyles.md` | 16.0pt | Normal | Regular | Standard card body text |
| `AppTextStyles.mdMedium` | 16.0pt | Medium (w500) | Regular | List tile titles |
| `AppTextStyles.mdBold` | 16.0pt | Bold (w700) | Regular | Action headers, section titles |
| `AppTextStyles.lg` | 20.0pt | SemiBold (w600) | Regular | AppBar titles, modal headers |
| `AppTextStyles.xl` | 24.0pt | Bold (w700) | Regular | Page hero titles |
| `AppTextStyles.xxl` | 32.0pt | Bold (w700) | Regular | Hero stats numbers |

---

## 3. 📐 Spacing & Grid System

All layouts **must** follow the 4pt/8pt grid system utilizing `AppSpacing` tokens in [`lib/core/theme/app_spacing.dart`](file:///Users/admin/Documents/mwstudioprojects/tvtimeapp/lib/core/theme/app_spacing.dart).

### Spacing Scale
- `AppSpacing.xxs` = **4.0pt**
- `AppSpacing.xs` = **8.0pt**
- `AppSpacing.sm` = **12.0pt**
- `AppSpacing.md` = **16.0pt** (Standard screen padding)
- `AppSpacing.lg` = **20.0pt**
- `AppSpacing.xl` = **24.0pt**
- `AppSpacing.xxl` = **32.0pt**
- `AppSpacing.xxxl` = **48.0pt**
- `AppSpacing.huge` = **64.0pt**

### Layout Helpers
- **Horizontal Gap Widgets**: `AppSpacing.gapW4`, `AppSpacing.gapW8`, `AppSpacing.gapW12`, `AppSpacing.gapW16`, `AppSpacing.gapW20`, `AppSpacing.gapW24`, `AppSpacing.gapW32`
- **Vertical Gap Widgets**: `AppSpacing.gapH4`, `AppSpacing.gapH8`, `AppSpacing.gapH12`, `AppSpacing.gapH16`, `AppSpacing.gapH20`, `AppSpacing.gapH24`, `AppSpacing.gapH32`, `AppSpacing.gapH48`
- **Padding Insets**: `AppSpacing.allXXS`, `AppSpacing.allXS`, `AppSpacing.allSM`, `AppSpacing.allMD`, `AppSpacing.allLG`, `AppSpacing.allXL`

---

## 4. 🧩 Component Conventions

### Cards & Surfaces
- **Border Radius**: Default card radius is **12.0pt** (`BorderRadius.circular(12)`).
- **Elevation**: Elevation `2.0` for content cards; `0.0` with subtle border for flat surfaces.
- **Background**: Uses `Theme.of(context).cardColor` or `AppColors.surfaceDarkAlt` in modals.

### Buttons & Interactive Targets
- **Elevated Button**: Primary brand action button with `AppColors.primary` background, `AppColors.textOnPrimary` text, bold 16pt font, 14pt vertical padding, 8pt border radius.
- **Destructive Button**: `AppColors.error` background with white text.
- **Touch Target Minimum**: Every interactive element (icon buttons, text buttons, cards) must maintain a minimum **48x48dp** touch target.

### Bottom Sheets & Modals
- **Shape**: `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)))` or `20.0pt`.
- **Background**: `AppColors.surfaceDarkAlt` in dark mode, modal background from theme.

---

## 5. 🚫 Non-Negotiable UI Rules

1. **No Hardcoded Hex Colors**: Never use `Color(0xFF...)` directly inside feature widget files. Use `AppColors` tokens.
2. **No Hardcoded Spacing**: Never use arbitrary pixel numbers like `SizedBox(height: 17)` or `EdgeInsets.all(19)`. Use `AppSpacing` tokens.
3. **Dark Mode First**: Support both Dark and Light mode dynamically via `Theme.of(context)`.
4. **Accessibility**: Ensure touch targets are >= 48x48dp and contrast complies with WCAG AA.
