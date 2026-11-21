// StyleBook "Amber & Ink" theme. Package: sb_ui (packages/sb_ui/lib/theme/sb_theme.dart)
// Shared by the Client, Partner and Admin apps. Requires: google_fonts. Flutter 3.27+.
//
// Usage:
//   MaterialApp(theme: SbTheme.light(), ...)
//   final sb = context.sb;  // tokens: sb.headerGradient, sb.shadowCard, ...

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Raw colour tokens (STYLEBOOK_FLUTTER_STYLE_GUIDE.md §2). Feature code should prefer Theme / context.sb.
abstract final class SbColors {
  // Brand
  static const ink = Color(0xFF141414);
  static const amber = Color(0xFFD9691F);
  static const amberDark = Color(0xFF9A4413);
  static const amberLight = Color(0xFFE07A2E);
  static const amberTint = Color(0xFFFBEADB);
  static const amberSurface = Color(0xFFFFF5EC);
  static const amberBorder = Color(0xFFF1C8A6);
  static const badgeYellow = Color(0xFFFFD43B);
  // Text
  static const text = Color(0xFF1A1512);
  static const text2 = Color(0xFF4A3E36);
  static const muted = Color(0xFF857469);
  static const subtle = Color(0xFFA2948A);
  static const navInactive = Color(0xFFA69A90);
  static const navInactiveLabelled = Color(0xFF8F847B);
  static const onDarkMuted = Color(0xFFBDB2A8);
  static const cocoa = Color(0xFF3B2A1F);
  // Surfaces and lines
  static const canvas = Color(0xFFF6EFE9);
  static const background = Color(0xFFF7F0E9);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF4EBE3);
  static const inputFill = Color(0xFFFFFCF8);
  static const border = Color(0xFFEEE3D9);
  static const borderStrong = Color(0xFFE7D9CC);
  static const inputBorder = Color(0xFFDDCBBD);
  static const darkLine = Color(0xFF4A443F);
  static const glowAmber = Color(0xFFFBE3CC);
  static const glowAmberSoft = Color(0x99FBE3CC); // glowAmber at 60 %
  static const dangerBorder = Color(0x40B42318); // danger at 25 %
  // Status
  static const success = Color(0xFF166534);
  static const successBg = Color(0xFFDCFCE7);
  static const successAction = Color(0xFF16A34A);
  static const warning = Color(0xFF92400E);
  static const warningBg = Color(0xFFFEF3C7);
  static const info = Color(0xFF1D4ED8);
  static const infoBg = Color(0xFFE0EAFF);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFEE4E2);
  static const star = Color(0xFFF5A524);
}

enum SbCategory { haircut, beard, facial, colour, spa, nails }

enum SbStatus { requested, confirmed, checkedIn, inService, completed, declined, expired, cancelled, noShow }

/// Theme extension: everything Material's ThemeData has no slot for.
@immutable
class SbTokens extends ThemeExtension<SbTokens> {
  const SbTokens({required this.priceLarge, required this.greeting, required this.cardName});

  final TextStyle priceLarge;
  final TextStyle greeting; // "Hey, Nimal": 40/300, -0.04em
  final TextStyle cardName; // name on portrait cards: 24/500

  // Gradients
  static const headerGradient = LinearGradient(
    begin: Alignment(-0.42, -1), // ~165°
    end: Alignment(0.42, 1),
    colors: [Color(0xFFF2A35A), Color(0xFFDD7326), Color(0xFFB9531B)],
    stops: [0, 0.45, 1],
  );
  static const promoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F1A17), Color(0xFF3A2A20), Color(0xFF7A3E18)],
    stops: [0, 0.55, 1],
  );
  static const partnerSidebar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF4EE), Color(0xFFF1E6DC)],
  );
  static const adminSidebar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141414), Color(0xFF1F1C1A)],
  );
  static const portraitFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00141010), Color(0xC7141010)],
  );
  static const heroGradients = <String, List<Color>>{
    'redbox': [Color(0xFFF2A35A), Color(0xFFB9531B)],
    'looks': [Color(0xFFE9B48A), Color(0xFF8E5A3C)],
    'serenity': [Color(0xFFC9B79A), Color(0xFF5E5240)],
    'fadefactory': [Color(0xFFC98B5B), Color(0xFF5A3A26)],
  };

  // Shadows (warm-tinted)
  static const shadowCard = [BoxShadow(offset: Offset(0, 6), blurRadius: 18, color: Color(0x0F3C2819))];
  static const shadowFloat = [BoxShadow(offset: Offset(0, 6), blurRadius: 18, color: Color(0x123C2819))];
  static const shadowPrimary = [BoxShadow(offset: Offset(0, 8), blurRadius: 18, color: Color(0x2E14100C))];
  static const shadowChip = [BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x4014100C))];
  static const shadowNav = [BoxShadow(offset: Offset(0, 12), blurRadius: 28, color: Color(0x4D14100C))];
  static const shadowHero = [BoxShadow(offset: Offset(0, 18), blurRadius: 36, color: Color(0x473C1E0A))];
  static const shadowSheet = [BoxShadow(offset: Offset(0, -8), blurRadius: 24, color: Color(0x1F1A1512))];

  // Radius
  static const rPill = 10.0;
  static const rSlot = 24.0;
  static const rChip = 20.0;
  static const rInput = 14.0;
  static const rButtonSecondary = 14.0;
  static const rOption = 14.0;
  static const rCard = 20.0;
  static const rListCard = 22.0;
  static const rSheet = 24.0;
  static const rButton = 26.0;
  static const rActionBar = 30.0;
  static const rPortrait = 32.0;
  static const rNav = 33.0;
  static const rHeader = 36.0;

  // Spacing
  static const screenPadding = 20.0;
  static const sectionTop = 26.0;
  static const sectionBottom = 10.0;
  static const gap4 = 4.0, gap8 = 8.0, gap12 = 12.0, gap16 = 16.0, gap20 = 20.0, gap24 = 24.0, gap32 = 32.0;

  // Sizes
  static const buttonHeight = 52.0;
  static const inputHeight = 48.0;
  static const minTouch = 44.0;
  static const glassButton = 46.0;
  static const dateChip = 54.0;
  static const slotHeight = 48.0;
  static const navHeight = 66.0;
  static const navActive = 50.0;
  static const actionBarHeight = 92.0;
  static const featuredCardHeight = 380.0;
  static const portraitHeaderHeight = 360.0;
  static const authCardMaxWidth = 440.0;
  static const wideBreakpoint = 900.0;
  static const iconSmall = 20.0;
  static const otpBoxWidth = 46.0;
  static const strokeThin = 2.0;
  static const strokeHairline = 1.0;
  static const strokeFocus = 1.5;

  // Font weights and states shared by widgets (never write FontWeight / opacity literals in widgets)
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;
  static const disabledOpacity = 0.4;

  /// Cream page with an amber glow (auth screens).
  static const authGlow = RadialGradient(
    center: Alignment(0.8, -0.8),
    radius: 1.2,
    colors: [SbColors.glowAmberSoft, SbColors.canvas],
  );

  static const _cat = {
    SbCategory.haircut: (Color(0xFFFBE6D6), Color(0xFFF6CDAE), Color(0xFF9A4413)),
    SbCategory.beard: (Color(0xFFFFEBD2), Color(0xFFFFD3A1), Color(0xFFB45309)),
    SbCategory.facial: (Color(0xFFECE6D4), Color(0xFFDCCFAE), Color(0xFF047857)),
    SbCategory.colour: (Color(0xFFF1E1D3), Color(0xFFE3C6AE), Color(0xFF7A4A2A)),
    SbCategory.spa: (Color(0xFFE9E2D8), Color(0xFFD6C8B6), Color(0xFF1D4ED8)),
    SbCategory.nails: (Color(0xFFF8E0D0), Color(0xFFEFC3A6), Color(0xFFA0461A)),
  };

  LinearGradient categoryGradient(SbCategory c) =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_cat[c]!.$1, _cat[c]!.$2]);
  Color categoryInk(SbCategory c) => _cat[c]!.$3;

  /// (label colour, background, client-facing label)
  (Color, Color, String) status(SbStatus s) => switch (s) {
        SbStatus.requested => (SbColors.warning, SbColors.warningBg, 'Waiting for salon'),
        SbStatus.confirmed => (SbColors.info, SbColors.infoBg, 'Confirmed'),
        SbStatus.checkedIn => (SbColors.warning, SbColors.warningBg, 'Checked in'),
        SbStatus.inService => (SbColors.amberDark, SbColors.amberTint, 'In service'),
        SbStatus.completed => (SbColors.success, SbColors.successBg, 'Completed'),
        SbStatus.declined => (SbColors.danger, SbColors.dangerBg, 'Declined by salon'),
        SbStatus.expired => (SbColors.muted, SbColors.soft, 'Expired'),
        SbStatus.cancelled => (SbColors.muted, SbColors.soft, 'Cancelled'),
        SbStatus.noShow => (SbColors.muted, SbColors.soft, 'No-show'),
      };

  static SbTokens light() => SbTokens(
        priceLarge: GoogleFonts.manrope(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: SbColors.text),
        greeting: GoogleFonts.manrope(
            fontSize: 40, height: 1.05, fontWeight: FontWeight.w300, letterSpacing: -1.6, color: const Color(0xFFFFF7EF)),
        cardName: GoogleFonts.manrope(
            fontSize: 24, height: 1.25, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Colors.white),
      );

  @override
  SbTokens copyWith() => this;

  @override
  SbTokens lerp(ThemeExtension<SbTokens>? other, double t) => this;
}

extension SbContext on BuildContext {
  SbTokens get sb => Theme.of(this).extension<SbTokens>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

abstract final class SbTheme {
  static TextTheme _text() {
    TextStyle m(double size, double lh, FontWeight w, {double ls = 0, Color c = SbColors.text}) =>
        GoogleFonts.manrope(fontSize: size, height: lh / size, fontWeight: w, letterSpacing: ls, color: c);
    return TextTheme(
      displayLarge: m(40, 42, FontWeight.w300, ls: -1.6),
      displayMedium: m(26, 30, FontWeight.w500, ls: -0.5),
      headlineMedium: m(27, 33, FontWeight.w600, ls: -0.8),
      headlineSmall: m(21, 27, FontWeight.w700, ls: -0.4),
      titleLarge: m(19, 25, FontWeight.w700, ls: -0.4),
      titleMedium: m(15, 21, FontWeight.w600),
      bodyLarge: m(15, 22, FontWeight.w400),
      bodyMedium: m(14, 20, FontWeight.w400),
      bodySmall: m(12, 17, FontWeight.w400, c: SbColors.muted),
      labelLarge: m(15, 20, FontWeight.w600),
      labelMedium: m(13, 18, FontWeight.w600),
      labelSmall: m(11, 14, FontWeight.w700),
    );
  }

  static ThemeData light() {
    final text = _text();
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: SbColors.ink,
      onPrimary: Colors.white,
      primaryContainer: SbColors.amberTint,
      onPrimaryContainer: SbColors.amberDark,
      secondary: SbColors.amber,
      onSecondary: Colors.white,
      tertiary: SbColors.amberLight,
      error: SbColors.danger,
      onError: Colors.white,
      errorContainer: SbColors.dangerBg,
      onErrorContainer: SbColors.danger,
      surface: SbColors.surface,
      onSurface: SbColors.text,
      onSurfaceVariant: SbColors.muted,
      surfaceContainerLowest: SbColors.surface,
      surfaceContainerLow: SbColors.canvas,
      surfaceContainer: SbColors.soft,
      outline: SbColors.borderStrong,
      outlineVariant: SbColors.border,
    );
    OutlineInputBorder ib(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(SbTokens.rInput), borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: SbColors.canvas,
      textTheme: text,
      extensions: [SbTokens.light()],
      splashFactory: InkRipple.splashFactory,
      dividerTheme: const DividerThemeData(color: SbColors.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: SbColors.text,
        titleTextStyle: text.headlineSmall,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: SbColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SbTokens.rCard),
          side: const BorderSide(color: SbColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SbColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(SbTokens.minTouch, SbTokens.buttonHeight),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(SbTokens.minTouch, SbTokens.minTouch),
          foregroundColor: SbColors.text,
          backgroundColor: SbColors.surface,
          side: const BorderSide(color: SbColors.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SbTokens.rButtonSecondary)),
          textStyle: text.labelMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: SbColors.amber, textStyle: text.labelMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SbColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: text.bodyLarge!.copyWith(color: SbColors.subtle),
        border: ib(SbColors.borderStrong),
        enabledBorder: ib(SbColors.borderStrong),
        focusedBorder: ib(SbColors.amberLight, 1.5),
        errorBorder: ib(SbColors.danger),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SbColors.surface,
        selectedColor: SbColors.ink,
        side: const BorderSide(color: SbColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SbTokens.rChip)),
        labelStyle: text.labelMedium!.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SbColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: SbColors.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(SbTokens.rSheet))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SbColors.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? SbColors.successAction : SbColors.inputBorder),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? SbColors.amber : const Color(0xFFD4C1B2)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? SbColors.amber : Colors.white),
        side: const BorderSide(color: Color(0xFFD4C1B2), width: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Core components. Feature widgets compose these; they never restyle them.
// ---------------------------------------------------------------------------

/// Primary action: black pill. Set [onDark] on dark or photo surfaces (white pill, black text).
class SbPrimaryButton extends StatelessWidget {
  const SbPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onDark = false,
    this.expand = true,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool onDark;
  final bool expand;

  /// Shows a progress indicator instead of the label and disables the button.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = onDark ? Colors.white : SbColors.ink;
    final fg = onDark ? SbColors.ink : Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || loading ? 1 : SbTokens.disabledOpacity,
        child: Material(
          color: bg,
          shape: const StadiumBorder(),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const StadiumBorder(),
            child: Container(
              width: expand ? double.infinity : null,
              constraints: const BoxConstraints(minHeight: SbTokens.buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: SbTokens.gap24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SbTokens.rButton),
                boxShadow: enabled && !onDark ? SbTokens.shadowPrimary : null,
              ),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox.square(
                      dimension: SbTokens.iconSmall,
                      child: CircularProgressIndicator(strokeWidth: SbTokens.strokeThin, color: fg),
                    )
                  : Text(label, textAlign: TextAlign.center, style: context.text.labelLarge!.copyWith(color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable chip. Off: white outlined. On: ink. Set [onHeader] for glass chips on the orange header.
class SbChoiceChip extends StatelessWidget {
  const SbChoiceChip({super.key, required this.label, required this.selected, required this.onTap, this.onHeader = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool onHeader;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color line;
    if (selected) {
      bg = SbColors.ink;
      fg = Colors.white;
      line = Colors.transparent;
    } else if (onHeader) {
      bg = Colors.white.withValues(alpha: 0.22);
      fg = Colors.white;
      line = Colors.white.withValues(alpha: 0.45);
    } else {
      bg = SbColors.surface;
      fg = SbColors.text;
      line = SbColors.borderStrong;
    }
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbTokens.rChip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 38),
          padding: EdgeInsets.symmetric(horizontal: onHeader ? 18 : 16, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(SbTokens.rChip),
            border: Border.all(color: line),
            boxShadow: selected && !onHeader ? SbTokens.shadowChip : null,
          ),
          child: Text(label,
              style: context.text.labelMedium!.copyWith(
                  color: fg, fontSize: onHeader ? 14 : 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        ),
      ),
    );
  }
}

/// White rounded card with warm shadow.
class SbCard extends StatelessWidget {
  const SbCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.radius = SbTokens.rCard});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: SbColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: SbColors.border),
          boxShadow: SbTokens.shadowCard,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Booking / order status pill. Always shows a word, never colour alone.
class SbStatusPill extends StatelessWidget {
  const SbStatusPill(this.status, {super.key, this.label});
  final SbStatus status;
  final String? label; // override, e.g. partner app shows "Requested"

  @override
  Widget build(BuildContext context) {
    final (fg, bg, text) = context.sb.status(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SbTokens.rPill)),
      child: Text(label ?? text, style: context.text.labelSmall!.copyWith(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Glass icon button for the orange header, with an optional count badge.
class SbGlassIconButton extends StatelessWidget {
  const SbGlassIconButton({super.key, required this.icon, required this.label, required this.onTap, this.badge});
  final IconData icon;
  final String label; // semantics
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: SbTokens.glassButton,
              height: SbTokens.glassButton,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: SbColors.badgeYellow),
                  child: Text('$badge',
                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: SbColors.ink)),
                ),
              ),
          ]),
        ),
      );
}

/// Round date chip (54). Selected = ink with white text.
class SbDateChip extends StatelessWidget {
  const SbDateChip({super.key, required this.weekday, required this.day, required this.selected, required this.onTap});
  final String weekday;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : SbColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: SbTokens.dateChip,
          height: SbTokens.dateChip,
          decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? SbColors.ink : SbColors.surface),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(weekday, style: context.text.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w500)),
            Text(day, style: context.text.titleMedium!.copyWith(color: fg, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

/// Pill time slot (48 h). Taken slots are struck through, not just greyed.
class SbSlotChip extends StatelessWidget {
  const SbSlotChip({super.key, required this.time, required this.selected, required this.taken, required this.onTap, this.offPeak = false});
  final String time;
  final bool selected;
  final bool taken;
  final bool offPeak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = taken ? SbColors.soft : (selected ? SbColors.ink : SbColors.surface);
    final fg = taken ? SbColors.subtle : (selected ? Colors.white : SbColors.text);
    return Semantics(
      button: !taken,
      enabled: !taken,
      selected: selected,
      label: taken ? '$time, taken' : time,
      child: InkWell(
        onTap: taken ? null : onTap,
        borderRadius: BorderRadius.circular(SbTokens.rSlot),
        child: Container(
          height: SbTokens.slotHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SbTokens.rSlot)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(time,
                style: context.text.bodyMedium!.copyWith(
                    color: fg, fontWeight: FontWeight.w600, decoration: taken ? TextDecoration.lineThrough : null)),
            if (offPeak && !taken)
              Text('15% off-peak',
                  style: context.text.labelSmall!.copyWith(fontSize: 10, color: selected ? Colors.white : SbColors.success)),
          ]),
        ),
      ),
    );
  }
}

/// 8-petal flower shape: r = 44% + 6%·cos(8θ) of the box, sampled at 96 points.
class SbFlowerBorder extends ShapeBorder {
  const SbFlowerBorder({this.petals = 8});
  final int petals;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    const n = 96;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final t = 2 * math.pi * i / n;
      final r = 0.44 + 0.06 * math.cos(petals * t);
      final p = Offset(rect.center.dx + r * rect.width * math.cos(t), rect.center.dy + r * rect.height * math.sin(t));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// Flower-cropped specialist portrait with distance (top) and free-time (bottom) badges.
class SbFlowerAvatar extends StatelessWidget {
  const SbFlowerAvatar({super.key, required this.image, this.size = 140, this.distance, this.freeLabel});
  final ImageProvider image;
  final double size;
  final String? distance; // "1.2 km"
  final String? freeLabel; // "Free 12:30 PM"

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          ClipPath(
            clipper: const ShapeBorderClipper(shape: SbFlowerBorder()),
            child: Image(image: image, width: size, height: size, fit: BoxFit.cover),
          ),
          if (distance != null)
            Positioned(top: -4, child: _badge(context, distance!, SbColors.ink, Colors.white, FontWeight.w700)),
          if (freeLabel != null)
            Positioned(bottom: 2, child: _badge(context, freeLabel!, Colors.white, SbColors.ink, FontWeight.w600, shadow: true)),
        ]),
      );

  Widget _badge(BuildContext context, String t, Color bg, Color fg, FontWeight w, {bool shadow = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          boxShadow: shadow ? const [BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x1F000000))] : null,
        ),
        child: Text(t, style: context.text.labelSmall!.copyWith(color: fg, fontWeight: w)),
      );
}

/// Large portrait card used for the featured specialist (home) and the profile header.
class SbPortraitCard extends StatelessWidget {
  const SbPortraitCard({
    super.key,
    required this.image,
    required this.name,
    required this.role,
    this.height = SbTokens.featuredCardHeight,
    this.topBadge,
    this.rating,
    this.onTap,
    this.trailing,
    this.action,
  });
  final ImageProvider image;
  final String name;
  final String role;
  final double height;
  final String? topBadge; // "Next free: Today 1:30 PM" or "9 years' experience"
  final String? rating;
  final VoidCallback? onTap;
  final Widget? trailing; // e.g. favourite button
  final Widget? action; // e.g. SbPrimaryButton(onDark: true, expand: false)

  @override
  Widget build(BuildContext context) {
    Widget circle(Widget child) => Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: child,
        );
    return Container(
      height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(SbTokens.rPortrait), boxShadow: SbTokens.shadowHero),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(SbTokens.rPortrait)),
      child: Material(
        color: SbColors.ink,
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            Image(image: image, fit: BoxFit.cover),
            const Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.55,
                widthFactor: 1,
                child: DecoratedBox(decoration: BoxDecoration(gradient: SbTokens.portraitFade)),
              ),
            ),
            if (topBadge != null)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: SbColors.ink.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
                  child: Text(topBadge!, style: context.text.labelSmall!.copyWith(color: Colors.white)),
                ),
              ),
            Positioned(
              left: 22,
              right: 22,
              bottom: action == null ? 22 : 92,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, style: context.sb.cardName),
                Text(role, style: context.text.bodySmall!.copyWith(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
              ]),
            ),
            if (action != null) Positioned(left: 22, bottom: 22, child: action!),
            Positioned(
              right: 20,
              bottom: 24,
              child: Row(children: [
                if (rating != null)
                  circle(Text('$rating★', style: context.text.labelMedium!.copyWith(color: SbColors.ink, fontWeight: FontWeight.w700))),
                if (trailing != null) ...[const SizedBox(width: 10), circle(trailing!)],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class SbNavItem {
  const SbNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Floating black bottom nav. Client: icon-only (labels go to Semantics). Partner mobile: [showLabels].
class SbFloatingNav extends StatelessWidget {
  const SbFloatingNav({super.key, required this.items, required this.index, required this.onTap, this.showLabels = false});
  final List<SbNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final bool showLabels;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: Container(
          height: SbTokens.navHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: SbColors.ink,
            borderRadius: BorderRadius.circular(SbTokens.rNav),
            boxShadow: SbTokens.shadowNav,
          ),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].label,
                  child: InkWell(
                    onTap: () => onTap(i),
                    customBorder: const StadiumBorder(),
                    child: showLabels ? _labelled(context, i) : _iconOnly(i),
                  ),
                ),
              ),
          ]),
        ),
      );

  Widget _iconOnly(int i) => Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: SbTokens.navActive,
          height: SbTokens.navActive,
          decoration: BoxDecoration(shape: BoxShape.circle, color: i == index ? Colors.white : Colors.transparent),
          child: Icon(items[i].icon, size: 22, color: i == index ? SbColors.ink : SbColors.navInactive),
        ),
      );

  Widget _labelled(BuildContext context, int i) {
    final c = i == index ? Colors.white : SbColors.navInactiveLabelled;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(items[i].icon, size: 22, color: c),
      const SizedBox(height: 4),
      Text(items[i].label, style: context.text.labelSmall!.copyWith(color: c, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Black action bar at the bottom of salon, choose-time and specialist screens.
class SbActionBar extends StatelessWidget {
  const SbActionBar({super.key, required this.title, required this.subtitle, required this.action, this.leading});
  final String title; // e.g. "with Kasun · LKR 2,000"
  final String subtitle; // e.g. "Thu 29 Oct, 9:30 AM"
  final Widget action; // SbPrimaryButton(onDark: true, expand: false)
  final Widget? leading; // optional outlined button (e.g. Chat)

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: SbTokens.actionBarHeight),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: SbColors.ink,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SbTokens.rActionBar)),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(subtitle, style: context.text.bodySmall!.copyWith(color: SbColors.onDarkMuted)),
              Text(title, style: context.text.titleMedium!.copyWith(color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 12),
          action,
        ]),
      );
}

/// The orange home header shell. Put the greeting row, pills and featured card inside [child].
class SbHomeHeader extends StatelessWidget {
  const SbHomeHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 6, 20, 22),
        decoration: const BoxDecoration(
          gradient: SbTokens.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(SbTokens.rHeader)),
        ),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
      );
}
