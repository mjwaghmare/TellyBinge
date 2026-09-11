# PopVerse Design System

This document outlines the core visual language, design tokens, typography,
spacing scale, component patterns, and UI rules for the **PopVerse** mobile
application.

---

## 1. 🎨 Color Palette & Theme Tokens

All color references in the application **must** consume `AppColors` tokens
defined in [`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart)
or semantic properties from `Theme.of(context)`. Direct raw hex colors in
widgets are strictly prohibited.

### Brand Colors
| Token Name | Hex Value | Preview | Usage |
| :--- | :--- | :--- | :--- |
| `AppColors.primary` | `#8B5CF6` | 🟣 Electric Violet | Primary brand accent (Dark Mode buttons, tabs, highlights) |
| `AppColors.lightPrimary` | `#7C3AED` | 🪻 Vivid Deep Violet | Primary brand accent in Light Mode (WCAG AA 5.8:1 contrast on white) |
| `AppColors.primaryDark` | `#6D28D9` | 🪻 Dark Violet | Pressed states, secondary brand accents |
| `AppColors.primaryLight` | `#A78BFA` | 💜 Light Violet | Dark mode highlights, badge background accents |
| `AppColors.lightPrimaryContainer` | `#F3E8FF` | 🪻 Soft Pastel Violet | Light mode active chip, tab, and progress track fills |
| `AppColors.lightOnPrimaryContainer` | `#6D28D9` | 🪻 Deep Violet | Text/icons on `lightPrimaryContainer` |

### Accent & Status Tokens
| Token Name | Dark / Default Hex | Light Tonal Container / Text | Usage |
| :--- | :--- | :--- | :--- |
| `AppColors.brandGreen` | `#6B8E23` | `#DCFCE7` / `#15803D` | TV Time green watch progress badges & checkmarks |
| `AppColors.accentBlue` | `#1E88E5` | `#DBEAFE` / `#1D4ED8` | Placeholder media icons & secondary action accents |
| `AppColors.watched` | `#8B5CF6` | `#F3E8FF` / `#7C3AED` | Watch progress bar fill & completed watch pills |
| `AppColors.airing` | `#2196F3` | `#DBEAFE` / `#1D4ED8` | Airing status tags for TV shows |
| `AppColors.ended` | `#757575` | `#F3F4F6` / `#4B5563` | Neutral status tag for ended shows |
| `AppColors.error` | `#E53935` | `#FEE2E2` / `#B91C1C` | Destructive buttons, error alerts, removing items |
| `AppColors.success` | `#4CAF50` | `#DCFCE7` / `#15803D` | Positive confirmations & watched badges |

### 3-Tier Surface Hierarchy (Dark & Light)
| Token Name | Dark Hex | Light Hex | Tier / Usage |
| :--- | :--- | :--- | :--- |
| `AppColors.background` / `darkBackground` | `#0D0D0D` | `#F9F9FB` | **Level 0 (Canvas):** Scaffold screen background |
| `AppColors.surface` | `#161616` | `#FFFFFF` | **Level 1 (Cards):** Content cards (elevation 0, 1px border: `#2C2C2E` / `#E5E7EB`) |
| `AppColors.surfaceElevated` | `#242424` | `#F3F4F6` | **Level 2 (Modals):** Bottom sheets, dialogs, inputs |
| `AppColors.borderDark` / `borderLight` | `#2C2C2E` | `#E5E7EB` | Dividers, chip outlines, input borders |

### Text Color Tokens
| Token Name | Dark Hex | Light Hex | Usage |
| :--- | :--- | :--- | :--- |
| `AppColors.textPrimary` | `#F4F4F5` | `#1F2937` | Primary body text and headers (92% off-white anti-halation in Dark) |
| `AppColors.textSecondary` | `#A1A1AA` | `#6B7280` | Subtitles, metadata, secondary text (balanced zinc neutral in Dark) |
| `AppColors.textTertiary` | `#71717A` | `#64748B` | Inactive icons, subtle text, placeholder hints |
| `AppColors.textOnPrimary` | `#FFFFFF` | `#FFFFFF` | Text rendered on top of `AppColors.primary` |

---

## 2. 🔤 Typography System

Typography is driven globally by **Google Fonts Plus Jakarta Sans** via `AppTheme` and `AppTextStyles` in
[`lib/core/theme/app_text_styles.dart`](lib/core/theme/app_text_styles.dart).

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

### Display Accent Fonts (Curated Highlights)
In addition to the primary Plus Jakarta Sans typeface, PopVerse uses two curated display accent fonts for cinematic personality:

| Style Token | Font Family | Style / Weight | Usage |
| :--- | :--- | :--- | :--- |
| `AppTextStyles.posterTitle` | **Bebas Neue** | Bold condensed (32pt) | Large landing hero billboard headlines |
| `AppTextStyles.posterHeader` | **Bebas Neue** | Bold condensed (22pt) | Movie & show section titles (`MOVIE INFO`, `CAST & CREW`) |
| `AppTextStyles.posterStat` | **Bebas Neue** | Bold condensed (22pt) | Live countdown digits & profile stat numbers |
| `AppTextStyles.editorialTagline`| **Playfair Display**| Italic serif (15pt) | Movie / TV show official taglines |
| `AppTextStyles.editorialQuote` | **Playfair Display**| Italic serif (17pt) | Critic reviews and spotlight editorial quotes |
| `AppTextStyles.editorialTitle` | **Playfair Display**| SemiBold serif (24pt) | Prestige festival / award-winner headers |

### Tabular Figures (`FontFeature.tabularFigures()`)
For live countdown timers, ratings, and stats counters, always apply `.withTabularFigures()` or `fontFeatures: const [FontFeature.tabularFigures()]` to ensure fixed-width digits and prevent UI jitter as numerical values update.

---

## 3. 📐 Spacing & Grid System

All layouts **must** follow the 4pt/8pt grid system utilizing `AppSpacing`
tokens in [`lib/core/theme/app_spacing.dart`](lib/core/theme/app_spacing.dart).

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
- **Horizontal Gap Widgets**: `AppSpacing.gapW4`, `AppSpacing.gapW8`,
  `AppSpacing.gapW12`, `AppSpacing.gapW16`, `AppSpacing.gapW20`,
  `AppSpacing.gapW24`, `AppSpacing.gapW32`
- **Vertical Gap Widgets**: `AppSpacing.gapH4`, `AppSpacing.gapH8`,
  `AppSpacing.gapH12`, `AppSpacing.gapH16`, `AppSpacing.gapH20`,
  `AppSpacing.gapH24`, `AppSpacing.gapH32`, `AppSpacing.gapH48`
- **Padding Insets**: `AppSpacing.allXXS`, `AppSpacing.allXS`,
  `AppSpacing.allSM`, `AppSpacing.allMD`, `AppSpacing.allLG`, `AppSpacing.allXL`

---

## 4. 🧩 Component Conventions

### Cards & Surfaces
- **Border Radius**: Default card radius is **12.0pt** (`BorderRadius.circular(12)`).
- **Elevation**: Elevation `2.0` for content cards; `0.0` with subtle border for flat surfaces.
- **Background**: Uses `Theme.of(context).cardColor` or `AppColors.surfaceDarkAlt` in modals.

### Buttons & Interactive Targets
- **Elevated Button**: Primary brand action button with `AppColors.primary`
  background, `AppColors.textOnPrimary` text, bold 16pt font, 14pt vertical
  padding, 8pt border radius.
- **Destructive Button**: `AppColors.error` background with white text.
- **Touch Target Minimum**: Every interactive element (icon buttons, text buttons, cards) must maintain a minimum **48x48dp** touch target.

### Bottom Sheets & Modals
- **Shape**: `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)))`
  or `20.0pt`.
- **Background**: `AppColors.surfaceDarkAlt` in dark mode, modal background from theme.

---

## 5. 🚫 Non-Negotiable UI Rules

1. **No Hardcoded Hex Colors**: Never use `Color(0xFF...)` directly inside
   feature widget files. Use `AppColors` tokens.
2. **No Hardcoded Spacing**: Never use arbitrary pixel numbers like
   `SizedBox(height: 17)` or `EdgeInsets.all(19)`. Use `AppSpacing` tokens.
3. **Dark Mode First**: Support both Dark and Light mode dynamically via `Theme.of(context)`.
4. **Accessibility**: Ensure touch targets are >= 48x48dp and contrast complies with WCAG AA.
