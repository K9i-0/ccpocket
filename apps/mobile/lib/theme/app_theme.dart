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
      surface: const Color(0xFFF4F4F5), // Zinc 100 (light grey bg)
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFAFAFA), // Zinc 50
      surfaceContainer: const Color(0xFFF4F4F5), // Zinc 100
      surfaceContainerHigh: Colors.white, // crisp white cards
      surfaceContainerHighest: const Color(0xFFE4E4E7), // Zinc 200
      primary: const Color(0xFF18181B), // Zinc 900 (near black primary)
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE4E4E7), // Zinc 200
      secondary: const Color(0xFF52525B), // Zinc 600
      onSecondary: Colors.white,
      tertiary: const Color(0xFF71717A), // Zinc 500
      error: const Color(0xFFDC2626), // Red 600
      onError: Colors.white,
      outline: const Color(0xFFA1A1AA), // Zinc 400
      outlineVariant: const Color(0xFFE4E4E7), // Zinc 200
    );

    return _buildTheme(colorScheme, Brightness.light, AppColors.light());
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      surface: const Color(0xFF09090B), // Zinc 950 (deep black bg)
      surfaceContainerLowest: const Color(0xFF000000), // Pure black
      surfaceContainerLow: const Color(0xFF18181B), // Zinc 900
      surfaceContainer: const Color(0xFF18181B), // Zinc 900
      surfaceContainerHigh: const Color(
        0xFF27272A,
      ), // Zinc 800 (clean grey cards)
      surfaceContainerHighest: const Color(0xFF3F3F46), // Zinc 700
      primary: const Color(0xFFFAFAFA), // Zinc 50 (white primary)
      onPrimary: const Color(0xFF18181B), // Zinc 900
      primaryContainer: const Color(0xFF3F3F46), // Zinc 700
      secondary: const Color(0xFFA1A1AA), // Zinc 400
      onSecondary: const Color(0xFF18181B), // Zinc 900
      tertiary: const Color(0xFF71717A), // Zinc 500
      error: const Color(0xFFEF4444), // Red 500
      onError: Colors.white,
      onSurface: const Color(0xFFF4F4F5), // Zinc 100
      onSurfaceVariant: const Color(0xFFA1A1AA), // Zinc 400
      outline: const Color(0xFF71717A), // Zinc 500
      outlineVariant: const Color(0xFF3F3F46), // Zinc 700
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
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
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

  // ---- Light (Monochrome palette) ----
  factory AppColors.light() => const AppColors(
    userBubble: Color(0xFF18181B), // Zinc 900 (near black)
    userBubbleText: Color(0xFFFFFFFF),
    assistantBubble: Color(0xFFF4F4F5), // Zinc 100
    toolBubble: Color(0xFFFAFAFA), // Zinc 50
    toolBubbleBorder: Color(0xFFE4E4E7), // Zinc 200
    toolIcon: Color(0xFF52525B), // Zinc 600
    errorBubble: Color(0xFFFEF2F2), // Red 50
    errorBubbleBorder: Color(0xFFEF4444), // Red 500
    errorText: Color(0xFFB91C1C), // Red 700
    permissionBubble: Color(0xFFFAFAFA), // Zinc 50
    permissionBubbleBorder: Color(0xFFE4E4E7), // Zinc 200
    permissionIcon: Color(0xFF18181B), // Zinc 900
    askBubble: Color(0xFFFAFAFA), // Zinc 50
    askBubbleBorder: Color(0xFFE4E4E7), // Zinc 200
    askIcon: Color(0xFF18181B), // Zinc 900
    systemChip: Color(0xFFF4F4F5), // Zinc 100
    successChip: Color(0xFFF0FDF4), // Green 50
    errorChip: Color(0xFFFEE2E2), // Red 100
    approvalBar: Color(0xFFF4F4F5), // Zinc 100
    approvalBarBorder: Color(0xFFE4E4E7), // Zinc 200
    statusStarting: Color(0xFF52525B), // Zinc 600
    statusRunning: Color(0xFF18181B), // Zinc 900
    statusApproval: Color(0xFF18181B), // Zinc 900
    statusIdle: Color(0xFFA1A1AA), // Zinc 400
    subtleText: Color(0xFF71717A), // Zinc 500
    codeBackground: Color(0xFFFAFAFA), // Zinc 50
    codeBorder: Color(0xFFE4E4E7), // Zinc 200
    toolResultBackground: Color(0xFFFAFAFA), // Zinc 50
    toolResultText: Color(0xFF71717A), // Zinc 500
    toolResultTextExpanded: Color(0xFF3F3F46), // Zinc 700
    diffAdditionBackground: Color(0xFFDCFCE7), // Green 100
    diffAdditionText: Color(0xFF166534), // Green 800
    diffDeletionBackground: Color(0xFFFEE2E2), // Red 100
    diffDeletionText: Color(0xFF991B1B), // Red 800
  );

  // ---- Dark (Monochrome palette) ----
  factory AppColors.dark() => const AppColors(
    userBubble: Color(0xFFFAFAFA), // Zinc 50 (white)
    userBubbleText: Color(0xFF18181B), // Zinc 900
    assistantBubble: Color(0xFF18181B), // Zinc 900
    toolBubble: Color(0xFF09090B), // Zinc 950
    toolBubbleBorder: Color(0xFF27272A), // Zinc 800
    toolIcon: Color(0xFFA1A1AA), // Zinc 400
    errorBubble: Color(0xFF450A0A), // Red 950
    errorBubbleBorder: Color(0xFF7F1D1D), // Red 900
    errorText: Color(0xFFFCA5A5), // Red 300
    permissionBubble: Color(0xFF09090B), // Zinc 950
    permissionBubbleBorder: Color(0xFF27272A), // Zinc 800
    permissionIcon: Color(0xFFFAFAFA), // Zinc 50
    askBubble: Color(0xFF09090B), // Zinc 950
    askBubbleBorder: Color(0xFF27272A), // Zinc 800
    askIcon: Color(0xFFFAFAFA), // Zinc 50
    systemChip: Color(0xFF18181B), // Zinc 900
    successChip: Color(0xFF052E16), // Green 950
    errorChip: Color(0xFF450A0A), // Red 950
    approvalBar: Color(0xFF18181B), // Zinc 900
    approvalBarBorder: Color(0xFF27272A), // Zinc 800
    statusStarting: Color(0xFFA1A1AA), // Zinc 400
    statusRunning: Color(0xFFFAFAFA), // Zinc 50
    statusApproval: Color(0xFFFAFAFA), // Zinc 50
    statusIdle: Color(0xFF52525B), // Zinc 600
    subtleText: Color(0xFFA1A1AA), // Zinc 400
    codeBackground: Color(0xFF09090B), // Zinc 950
    codeBorder: Color(0xFF27272A), // Zinc 800
    toolResultBackground: Color(0xFF09090B), // Zinc 950
    toolResultText: Color(0xFFA1A1AA), // Zinc 400
    toolResultTextExpanded: Color(0xFFF4F4F5), // Zinc 100
    diffAdditionBackground: Color(0xFF052E16), // Green 950
    diffAdditionText: Color(0xFF86EFAC), // Green 300
    diffDeletionBackground: Color(0xFF450A0A), // Red 950
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
