import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// AppTheme: Indigo-Cyan design system (Poppins + Inter typography)
// ---------------------------------------------------------------------------

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      surface: const Color(0xFFFAFAFC),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF8F9FB),
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFE2E8F0),
      surfaceContainerHighest: const Color(0xFFCBD5E1),
      primary: const Color(0xFF4F46E5), // Indigo 600
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE0E7FF),
      secondary: const Color(0xFF0891B2), // Cyan 600
      onSecondary: Colors.white,
      tertiary: const Color(0xFFDB2777), // Pink 600
      error: const Color(0xFFDC2626), // Red 600
      onError: Colors.white,
      outline: const Color(0xFF94A3B8),
      outlineVariant: const Color(0xFFE2E8F0),
    );

    return _buildTheme(colorScheme, Brightness.light, AppColors.light());
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      surface: const Color(0xFF0D0D12),
      surfaceContainerLowest: const Color(0xFF0D0D12),
      surfaceContainerLow: const Color(0xFF141419),
      surfaceContainer: const Color(0xFF1A1A21),
      surfaceContainerHigh: const Color(0xFF22222B),
      surfaceContainerHighest: const Color(0xFF2A2A35),
      primary: const Color(0xFF818CF8), // Indigo 400
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF4F46E5),
      secondary: const Color(0xFF22D3EE), // Cyan 400
      onSecondary: Colors.black,
      tertiary: const Color(0xFFF472B6), // Pink 400
      error: const Color(0xFFF87171), // Red 400
      onError: Colors.black,
      outline: const Color(0xFF4A4A5A),
      outlineVariant: const Color(0xFF2A2A35),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.outline,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.outline,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return baseTextTheme.copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: colorScheme.onSurface,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: colorScheme.onSurface,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppColors: Semantic color tokens (ThemeExtension)
// Harmonised with the Indigo-Cyan palette
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
    required this.statusRunning,
    required this.statusApproval,
    required this.statusIdle,
    required this.subtleText,
    required this.codeBackground,
    required this.codeBorder,
    required this.toolResultBackground,
    required this.toolResultText,
    required this.toolResultTextExpanded,
  });

  // ---- Light (Indigo-Cyan palette) ----
  factory AppColors.light() => const AppColors(
    userBubble: Color(0xFF4F46E5),       // Indigo 600
    userBubbleText: Color(0xFFFFFFFF),
    assistantBubble: Color(0xFFE0E7FF),  // Indigo 100
    toolBubble: Color(0xFFECFDF5),       // Emerald 50
    toolBubbleBorder: Color(0xFF6EE7B7), // Emerald 300
    toolIcon: Color(0xFF059669),         // Emerald 600
    errorBubble: Color(0xFFFEF2F2),      // Red 50
    errorBubbleBorder: Color(0xFFFCA5A5), // Red 300
    errorText: Color(0xFFDC2626),        // Red 600
    permissionBubble: Color(0xFFFFFBEB), // Amber 50
    permissionBubbleBorder: Color(0xFFFCD34D), // Amber 300
    permissionIcon: Color(0xFFD97706),   // Amber 600
    askBubble: Color(0xFFEDE9FE),        // Violet 100
    askBubbleBorder: Color(0xFFC4B5FD),  // Violet 300
    askIcon: Color(0xFF7C3AED),          // Violet 600
    systemChip: Color(0xFFE0F2FE),       // Sky 100
    successChip: Color(0xFFD1FAE5),      // Emerald 100
    errorChip: Color(0xFFFEE2E2),        // Red 100
    approvalBar: Color(0xFFFEF3C7),      // Amber 100
    approvalBarBorder: Color(0xFFFCD34D), // Amber 300
    statusRunning: Color(0xFF059669),     // Emerald 600
    statusApproval: Color(0xFFD97706),   // Amber 600
    statusIdle: Color(0xFF94A3B8),       // Slate 400
    subtleText: Color(0xFF64748B),       // Slate 500
    codeBackground: Color(0xFFF1F5F9),   // Slate 100
    codeBorder: Color(0xFFE2E8F0),       // Slate 200
    toolResultBackground: Color(0xFFF1F5F9),
    toolResultText: Color(0xFF64748B),
    toolResultTextExpanded: Color(0xFF334155), // Slate 700
  );

  // ---- Dark (Indigo-Cyan palette) ----
  factory AppColors.dark() => const AppColors(
    userBubble: Color(0xFF818CF8),       // Indigo 400
    userBubbleText: Color(0xFFFFFFFF),
    assistantBubble: Color(0xFF1E1B4B),  // Indigo 950
    toolBubble: Color(0xFF0C2A1E),       // Deep emerald
    toolBubbleBorder: Color(0xFF1A5C3A),
    toolIcon: Color(0xFF6EE7B7),         // Emerald 300
    errorBubble: Color(0xFF2A1215),
    errorBubbleBorder: Color(0xFF5C2020),
    errorText: Color(0xFFFCA5A5),        // Red 300
    permissionBubble: Color(0xFF2A2410),
    permissionBubbleBorder: Color(0xFF5C4A1A),
    permissionIcon: Color(0xFFFCD34D),   // Amber 300
    askBubble: Color(0xFF1E1533),
    askBubbleBorder: Color(0xFF4C3A6B),
    askIcon: Color(0xFFC4B5FD),          // Violet 300
    systemChip: Color(0xFF0C1929),
    successChip: Color(0xFF0C2A1E),
    errorChip: Color(0xFF2A1215),
    approvalBar: Color(0xFF2A2410),
    approvalBarBorder: Color(0xFF5C4A1A),
    statusRunning: Color(0xFF6EE7B7),    // Emerald 300
    statusApproval: Color(0xFFFCD34D),   // Amber 300
    statusIdle: Color(0xFF4A4A5A),
    subtleText: Color(0xFF94A3B8),       // Slate 400
    codeBackground: Color(0xFF141419),
    codeBorder: Color(0xFF2A2A35),
    toolResultBackground: Color(0xFF141419),
    toolResultText: Color(0xFF94A3B8),
    toolResultTextExpanded: Color(0xFFCBD5E1), // Slate 300
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
    Color? statusRunning,
    Color? statusApproval,
    Color? statusIdle,
    Color? subtleText,
    Color? codeBackground,
    Color? codeBorder,
    Color? toolResultBackground,
    Color? toolResultText,
    Color? toolResultTextExpanded,
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
      permissionBubbleBorder: permissionBubbleBorder ?? this.permissionBubbleBorder,
      permissionIcon: permissionIcon ?? this.permissionIcon,
      askBubble: askBubble ?? this.askBubble,
      askBubbleBorder: askBubbleBorder ?? this.askBubbleBorder,
      askIcon: askIcon ?? this.askIcon,
      systemChip: systemChip ?? this.systemChip,
      successChip: successChip ?? this.successChip,
      errorChip: errorChip ?? this.errorChip,
      approvalBar: approvalBar ?? this.approvalBar,
      approvalBarBorder: approvalBarBorder ?? this.approvalBarBorder,
      statusRunning: statusRunning ?? this.statusRunning,
      statusApproval: statusApproval ?? this.statusApproval,
      statusIdle: statusIdle ?? this.statusIdle,
      subtleText: subtleText ?? this.subtleText,
      codeBackground: codeBackground ?? this.codeBackground,
      codeBorder: codeBorder ?? this.codeBorder,
      toolResultBackground: toolResultBackground ?? this.toolResultBackground,
      toolResultText: toolResultText ?? this.toolResultText,
      toolResultTextExpanded: toolResultTextExpanded ?? this.toolResultTextExpanded,
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
      toolBubbleBorder: Color.lerp(toolBubbleBorder, other.toolBubbleBorder, t)!,
      toolIcon: Color.lerp(toolIcon, other.toolIcon, t)!,
      errorBubble: Color.lerp(errorBubble, other.errorBubble, t)!,
      errorBubbleBorder: Color.lerp(errorBubbleBorder, other.errorBubbleBorder, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      permissionBubble: Color.lerp(permissionBubble, other.permissionBubble, t)!,
      permissionBubbleBorder: Color.lerp(permissionBubbleBorder, other.permissionBubbleBorder, t)!,
      permissionIcon: Color.lerp(permissionIcon, other.permissionIcon, t)!,
      askBubble: Color.lerp(askBubble, other.askBubble, t)!,
      askBubbleBorder: Color.lerp(askBubbleBorder, other.askBubbleBorder, t)!,
      askIcon: Color.lerp(askIcon, other.askIcon, t)!,
      systemChip: Color.lerp(systemChip, other.systemChip, t)!,
      successChip: Color.lerp(successChip, other.successChip, t)!,
      errorChip: Color.lerp(errorChip, other.errorChip, t)!,
      approvalBar: Color.lerp(approvalBar, other.approvalBar, t)!,
      approvalBarBorder: Color.lerp(approvalBarBorder, other.approvalBarBorder, t)!,
      statusRunning: Color.lerp(statusRunning, other.statusRunning, t)!,
      statusApproval: Color.lerp(statusApproval, other.statusApproval, t)!,
      statusIdle: Color.lerp(statusIdle, other.statusIdle, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      codeBorder: Color.lerp(codeBorder, other.codeBorder, t)!,
      toolResultBackground: Color.lerp(toolResultBackground, other.toolResultBackground, t)!,
      toolResultText: Color.lerp(toolResultText, other.toolResultText, t)!,
      toolResultTextExpanded: Color.lerp(toolResultTextExpanded, other.toolResultTextExpanded, t)!,
    );
  }
}
