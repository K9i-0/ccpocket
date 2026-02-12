import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// AppTheme: Graphite & Ember design system (Space Grotesk + IBM Plex Sans)
//
// Warm editorial palette. Dominant burnt-orange primary with muted teal
// accent. Warm stone surfaces instead of cool slates. Inspired by IDE themes
// and professional developer tools — deliberately avoids the "AI purple
// gradient on white" cliché.
// ---------------------------------------------------------------------------

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      surface: const Color(0xFFFAFAF7), // warm ivory
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F6F3), // warm paper
      surfaceContainer: const Color(0xFFF0EEEB), // warm light grey (brighter)
      surfaceContainerHigh: const Color(0xFFF5F2EF), // card bg (bright)
      surfaceContainerHighest: const Color(0xFFEAE7E4), // warm mid
      primary: const Color(0xFFD4450A), // Ember (brighter)
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFF0E0), // warm Orange 100
      secondary: const Color(0xFF0D9488), // Teal 600 (brighter accent)
      onSecondary: Colors.white,
      tertiary: const Color(0xFF92400E), // Amber 800 (subtle warm variant)
      error: const Color(0xFFB91C1C), // Red 700
      onError: Colors.white,
      outline: const Color(0xFF787068), // warm grey (WCAG AA)
      outlineVariant: const Color(0xFFC7C2BC), // warm light border (refined)
    );

    return _buildTheme(colorScheme, Brightness.light, AppColors.light());
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      surface: const Color(0xFF131211), // warm near-black
      surfaceContainerLowest: const Color(0xFF131211),
      surfaceContainerLow: const Color(0xFF1A1917), // warm dark
      surfaceContainer: const Color(0xFF21201D), // warm dark grey
      surfaceContainerHigh: const Color(0xFF2B2A26),
      surfaceContainerHighest: const Color(0xFF353330),
      primary: const Color(0xFFF97316), // Orange 500 (brighter for dark)
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFC2410C),
      secondary: const Color(0xFF2DD4BF), // Teal 300 (bright for dark)
      onSecondary: Colors.black,
      tertiary: const Color(0xFFFBBF24), // Amber 400
      error: const Color(0xFFF87171), // Red 400
      onError: Colors.black,
      outline: const Color(0xFF5C5750), // warm dark grey
      outlineVariant: const Color(0xFF353330),
    );

    return _buildTheme(colorScheme, Brightness.dark, AppColors.dark());
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    Brightness brightness,
    AppColors appColors,
  ) {
    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: [appColors],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
        color: colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: colorScheme.outline, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // DropdownMenu
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),

      // Icon
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),

      // ListTile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final baseTextTheme = GoogleFonts.ibmPlexSansTextTheme();

    // Headlines: Space Grotesk — geometric, distinctive, avoids generic Poppins
    // Body/Labels: IBM Plex Sans — professional & readable, avoids generic Inter
    return baseTextTheme.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.ibmPlexSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: colorScheme.onSurface,
      ),
      titleSmall: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: colorScheme.onSurface,
      ),
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      labelMedium: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: colorScheme.onSurface,
      ),
      labelSmall: GoogleFonts.ibmPlexSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppColors: Semantic color tokens (ThemeExtension)
// Harmonised with the Graphite & Ember palette
// ---------------------------------------------------------------------------

class AppColors extends ThemeExtension<AppColors> {
  // User bubble
  final Color userBubble;
  final Color userBubbleText;

  // Assistant bubble
  final Color assistantBubble;

  // Tool use
  final Color toolBubble;
  final Color toolBubbleBorder;
  final Color toolIcon;

  // Error
  final Color errorBubble;
  final Color errorBubbleBorder;
  final Color errorText;

  // Permission
  final Color permissionBubble;
  final Color permissionBubbleBorder;
  final Color permissionIcon;

  // Ask
  final Color askBubble;
  final Color askBubbleBorder;
  final Color askIcon;

  // Chips
  final Color systemChip;
  final Color successChip;
  final Color errorChip;

  // Approval bar
  final Color approvalBar;
  final Color approvalBarBorder;

  // Status
  final Color statusStarting;
  final Color statusRunning;
  final Color statusApproval;
  final Color statusIdle;

  // Subtle text
  final Color subtleText;

  // Code block
  final Color codeBackground;
  final Color codeBorder;

  // Tool result
  final Color toolResultBackground;
  final Color toolResultText;
  final Color toolResultTextExpanded;

  // Diff viewer
  final Color diffAdditionBackground;
  final Color diffAdditionText;
  final Color diffDeletionBackground;
  final Color diffDeletionText;

  const AppColors({
    required this.userBubble,
    required this.userBubbleText,
    required this.assistantBubble,
    required this.toolBubble,
    required this.toolBubbleBorder,
    required this.toolIcon,
    required this.errorBubble,
    required this.errorBubbleBorder,
    required this.errorText,
    required this.permissionBubble,
    required this.permissionBubbleBorder,
    required this.permissionIcon,
    required this.askBubble,
    required this.askBubbleBorder,
    required this.askIcon,
    required this.systemChip,
    required this.successChip,
    required this.errorChip,
    required this.approvalBar,
    required this.approvalBarBorder,
    required this.statusStarting,
    required this.statusRunning,
    required this.statusApproval,
    required this.statusIdle,
    required this.subtleText,
    required this.codeBackground,
    required this.codeBorder,
    required this.toolResultBackground,
    required this.toolResultText,
    required this.toolResultTextExpanded,
    required this.diffAdditionBackground,
    required this.diffAdditionText,
    required this.diffDeletionBackground,
    required this.diffDeletionText,
  });

  // ---- Light (Graphite & Ember palette) ----
  factory AppColors.light() => const AppColors(
    userBubble: Color(0xFFD4450A), // Ember (brighter)
    userBubbleText: Color(0xFFFFFFFF),
    assistantBubble: Color(0xFFF3F0EE), // warm cream (refined)
    toolBubble: Color(0xFFF0FDFA), // Teal 50
    toolBubbleBorder: Color(0xFF5EEAD4), // Teal 300
    toolIcon: Color(0xFF0F766E), // Teal 700
    errorBubble: Color(0xFFFEF2F2), // Red 50
    errorBubbleBorder: Color(0xFFEF4444), // Red 500
    errorText: Color(0xFFB91C1C), // Red 700
    permissionBubble: Color(0xFFFFF7ED), // Orange 50
    permissionBubbleBorder: Color(0xFFD97706), // Amber 600
    permissionIcon: Color(0xFFD4450A), // Ember (match primary)
    askBubble: Color(0xFFFFF7ED), // Orange 50
    askBubbleBorder: Color(0xFFD97706), // Amber 600
    askIcon: Color(0xFF9A3412), // Orange 800
    systemChip: Color(0xFFF0FDFA), // Teal 50 (unified)
    successChip: Color(0xFFF0FDF4), // Green 50
    errorChip: Color(0xFFFEE2E2), // Red 100
    approvalBar: Color(0xFFFFF7ED), // Orange 50
    approvalBarBorder: Color(0xFFD4450A), // Ember (unified)
    statusStarting: Color(0xFF4F46E5), // Indigo 600
    statusRunning: Color(0xFF0D9488), // Teal 600 (brighter)
    statusApproval: Color(0xFFD4450A), // Ember (brighter)
    statusIdle: Color(0xFF787068), // warm grey (WCAG AA)
    subtleText: Color(0xFF6B5E54), // warm stone (WCAG AA)
    codeBackground: Color(0xFFF5F0EB), // warm cream
    codeBorder: Color(0xFF99D5CF), // Teal accent border
    toolResultBackground: Color(0xFFF5F0EB),
    toolResultText: Color(0xFF6B5E54), // warm stone (WCAG AA)
    toolResultTextExpanded: Color(0xFF44403C), // Stone 700
    diffAdditionBackground: Color(0xFFDCFCE7), // Green 100
    diffAdditionText: Color(0xFF166534), // Green 800
    diffDeletionBackground: Color(0xFFFEE2E2), // Red 100
    diffDeletionText: Color(0xFF991B1B), // Red 800
  );

  // ---- Dark (Graphite & Ember palette) ----
  factory AppColors.dark() => const AppColors(
    userBubble: Color(0xFFF97316), // Orange 500
    userBubbleText: Color(0xFFFFFFFF),
    assistantBubble: Color(0xFF1E1D1A), // warm very dark
    toolBubble: Color(0xFF0A1F12), // deep green
    toolBubbleBorder: Color(0xFF1A5C35),
    toolIcon: Color(0xFF86EFAC), // Green 300
    errorBubble: Color(0xFF2A1215),
    errorBubbleBorder: Color(0xFF5C2020),
    errorText: Color(0xFFFCA5A5), // Red 300
    permissionBubble: Color(0xFF261A0B), // deep warm
    permissionBubbleBorder: Color(0xFF5C3D15),
    permissionIcon: Color(0xFFFDBA74), // Orange 300
    askBubble: Color(0xFF261A0B), // deep warm
    askBubbleBorder: Color(0xFF5C3D15),
    askIcon: Color(0xFFFDBA74), // Orange 300
    systemChip: Color(0xFF0F1A16), // warm dark green
    successChip: Color(0xFF0A1F12),
    errorChip: Color(0xFF2A1215),
    approvalBar: Color(0xFF261A0B),
    approvalBarBorder: Color(0xFF5C3D15),
    statusStarting: Color(0xFF93C5FD), // Blue 300
    statusRunning: Color(0xFF86EFAC), // Green 300
    statusApproval: Color(0xFFFDBA74), // Orange 300
    statusIdle: Color(0xFF5C5750), // warm dark grey
    subtleText: Color(0xFFA8A29E), // Stone 400
    codeBackground: Color(0xFF1A1917),
    codeBorder: Color(0xFF353330),
    toolResultBackground: Color(0xFF1A1917),
    toolResultText: Color(0xFFA8A29E), // Stone 400
    toolResultTextExpanded: Color(0xFFD6D3D1), // Stone 300
    diffAdditionBackground: Color(0xFF14532D), // Green 900
    diffAdditionText: Color(0xFF86EFAC), // Green 300
    diffDeletionBackground: Color(0xFF7F1D1D), // Red 900
    diffDeletionText: Color(0xFFFCA5A5), // Red 300
  );

  @override
  AppColors copyWith({
    Color? userBubble,
    Color? userBubbleText,
    Color? assistantBubble,
    Color? toolBubble,
    Color? toolBubbleBorder,
    Color? toolIcon,
    Color? errorBubble,
    Color? errorBubbleBorder,
    Color? errorText,
    Color? permissionBubble,
    Color? permissionBubbleBorder,
    Color? permissionIcon,
    Color? askBubble,
    Color? askBubbleBorder,
    Color? askIcon,
    Color? systemChip,
    Color? successChip,
    Color? errorChip,
    Color? approvalBar,
    Color? approvalBarBorder,
    Color? statusStarting,
    Color? statusRunning,
    Color? statusApproval,
    Color? statusIdle,
    Color? subtleText,
    Color? codeBackground,
    Color? codeBorder,
    Color? toolResultBackground,
    Color? toolResultText,
    Color? toolResultTextExpanded,
    Color? diffAdditionBackground,
    Color? diffAdditionText,
    Color? diffDeletionBackground,
    Color? diffDeletionText,
  }) {
    return AppColors(
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      toolBubble: toolBubble ?? this.toolBubble,
      toolBubbleBorder: toolBubbleBorder ?? this.toolBubbleBorder,
      toolIcon: toolIcon ?? this.toolIcon,
      errorBubble: errorBubble ?? this.errorBubble,
      errorBubbleBorder: errorBubbleBorder ?? this.errorBubbleBorder,
      errorText: errorText ?? this.errorText,
      permissionBubble: permissionBubble ?? this.permissionBubble,
      permissionBubbleBorder:
          permissionBubbleBorder ?? this.permissionBubbleBorder,
      permissionIcon: permissionIcon ?? this.permissionIcon,
      askBubble: askBubble ?? this.askBubble,
      askBubbleBorder: askBubbleBorder ?? this.askBubbleBorder,
      askIcon: askIcon ?? this.askIcon,
      systemChip: systemChip ?? this.systemChip,
      successChip: successChip ?? this.successChip,
      errorChip: errorChip ?? this.errorChip,
      approvalBar: approvalBar ?? this.approvalBar,
      approvalBarBorder: approvalBarBorder ?? this.approvalBarBorder,
      statusStarting: statusStarting ?? this.statusStarting,
      statusRunning: statusRunning ?? this.statusRunning,
      statusApproval: statusApproval ?? this.statusApproval,
      statusIdle: statusIdle ?? this.statusIdle,
      subtleText: subtleText ?? this.subtleText,
      codeBackground: codeBackground ?? this.codeBackground,
      codeBorder: codeBorder ?? this.codeBorder,
      toolResultBackground: toolResultBackground ?? this.toolResultBackground,
      toolResultText: toolResultText ?? this.toolResultText,
      toolResultTextExpanded:
          toolResultTextExpanded ?? this.toolResultTextExpanded,
      diffAdditionBackground:
          diffAdditionBackground ?? this.diffAdditionBackground,
      diffAdditionText: diffAdditionText ?? this.diffAdditionText,
      diffDeletionBackground:
          diffDeletionBackground ?? this.diffDeletionBackground,
      diffDeletionText: diffDeletionText ?? this.diffDeletionText,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleText: Color.lerp(userBubbleText, other.userBubbleText, t)!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      toolBubble: Color.lerp(toolBubble, other.toolBubble, t)!,
      toolBubbleBorder: Color.lerp(
        toolBubbleBorder,
        other.toolBubbleBorder,
        t,
      )!,
      toolIcon: Color.lerp(toolIcon, other.toolIcon, t)!,
      errorBubble: Color.lerp(errorBubble, other.errorBubble, t)!,
      errorBubbleBorder: Color.lerp(
        errorBubbleBorder,
        other.errorBubbleBorder,
        t,
      )!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      permissionBubble: Color.lerp(
        permissionBubble,
        other.permissionBubble,
        t,
      )!,
      permissionBubbleBorder: Color.lerp(
        permissionBubbleBorder,
        other.permissionBubbleBorder,
        t,
      )!,
      permissionIcon: Color.lerp(permissionIcon, other.permissionIcon, t)!,
      askBubble: Color.lerp(askBubble, other.askBubble, t)!,
      askBubbleBorder: Color.lerp(askBubbleBorder, other.askBubbleBorder, t)!,
      askIcon: Color.lerp(askIcon, other.askIcon, t)!,
      systemChip: Color.lerp(systemChip, other.systemChip, t)!,
      successChip: Color.lerp(successChip, other.successChip, t)!,
      errorChip: Color.lerp(errorChip, other.errorChip, t)!,
      approvalBar: Color.lerp(approvalBar, other.approvalBar, t)!,
      approvalBarBorder: Color.lerp(
        approvalBarBorder,
        other.approvalBarBorder,
        t,
      )!,
      statusStarting: Color.lerp(statusStarting, other.statusStarting, t)!,
      statusRunning: Color.lerp(statusRunning, other.statusRunning, t)!,
      statusApproval: Color.lerp(statusApproval, other.statusApproval, t)!,
      statusIdle: Color.lerp(statusIdle, other.statusIdle, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      codeBorder: Color.lerp(codeBorder, other.codeBorder, t)!,
      toolResultBackground: Color.lerp(
        toolResultBackground,
        other.toolResultBackground,
        t,
      )!,
      toolResultText: Color.lerp(toolResultText, other.toolResultText, t)!,
      toolResultTextExpanded: Color.lerp(
        toolResultTextExpanded,
        other.toolResultTextExpanded,
        t,
      )!,
      diffAdditionBackground: Color.lerp(
        diffAdditionBackground,
        other.diffAdditionBackground,
        t,
      )!,
      diffAdditionText: Color.lerp(
        diffAdditionText,
        other.diffAdditionText,
        t,
      )!,
      diffDeletionBackground: Color.lerp(
        diffDeletionBackground,
        other.diffDeletionBackground,
        t,
      )!,
      diffDeletionText: Color.lerp(
        diffDeletionText,
        other.diffDeletionText,
        t,
      )!,
    );
  }
}
