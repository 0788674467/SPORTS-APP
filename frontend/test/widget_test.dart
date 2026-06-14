import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sports_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AppColors', () {
    test('has primary navy color', () {
      expect(AppColors.mmwNavy, const Color(0xFF003087));
    });

    test('has secondary green', () {
      expect(AppColors.mmwGreen, const Color(0xFF00A651));
    });

    test('has tertiary gold', () {
      expect(AppColors.mmwGold, const Color(0xFFF5A500));
    });
  });

  group('AppTheme', () {
    testWidgets('lightTheme creates valid theme data', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, AppColors.mmwNavy);
      expect(theme.colorScheme.secondary, AppColors.mmwGreen);
      expect(theme.colorScheme.tertiary, AppColors.mmwGold);
      expect(theme.useMaterial3, true);
      await tester.pumpAndSettle();
    });

    testWidgets('darkTheme creates valid theme data', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, true);
      await tester.pumpAndSettle();
    });

    testWidgets('light theme app bar has navy background', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.backgroundColor, AppColors.mmwNavy);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
      await tester.pumpAndSettle();
    });

    testWidgets('light theme has elevated button styling', (tester) async {
      final theme = AppTheme.lightTheme;
      final buttonStyle = theme.elevatedButtonTheme.style;
      expect(buttonStyle, isNotNull);
      await tester.pumpAndSettle();
    });

    testWidgets('light theme card has border radius', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      await tester.pumpAndSettle();
    });
  });
}
