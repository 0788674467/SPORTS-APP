import 'package:flutter_test/flutter_test.dart';
import 'package:sports_app/core/state/app_state.dart';

void main() {
  group('AppState', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      // Reset to default state for each test — disable Supabase calls
      appState.setSeasonLabel('Season 2026 underway');
      appState.toggleDarkMode(false);
      appState.setLanguage(AppLanguage.english);
    });

    test('initial values are correct', () {
      expect(appState.isDarkMode, false);
      expect(appState.language, AppLanguage.english);
      expect(appState.seasonLabel, 'Season 2026 underway');
    });

    group('toggleDarkMode', () {
      test('toggles dark mode on', () {
        appState.toggleDarkMode(true);
        expect(appState.isDarkMode, true);
      });

      test('toggles dark mode off', () {
        appState.toggleDarkMode(true);
        appState.toggleDarkMode(false);
        expect(appState.isDarkMode, false);
      });
    });

    group('setSeasonLabel', () {
      test('updates season label', () {
        appState.setSeasonLabel('Season 2026/27');
        expect(appState.seasonLabel, 'Season 2026/27');
      });

      test('ignores empty string', () {
        appState.setSeasonLabel('Original');
        appState.setSeasonLabel('');
        expect(appState.seasonLabel, 'Original');
      });

      test('ignores whitespace-only string', () {
        appState.setSeasonLabel('Original');
        appState.setSeasonLabel('   ');
        expect(appState.seasonLabel, 'Original');
      });
    });

    group('setLanguage', () {
      test('sets language to Kiswahili', () {
        appState.setLanguage(AppLanguage.kiswahili);
        expect(appState.language, AppLanguage.kiswahili);
      });

      test('sets language back to English', () {
        appState.setLanguage(AppLanguage.kiswahili);
        appState.setLanguage(AppLanguage.english);
        expect(appState.language, AppLanguage.english);
      });
    });

    group('translate', () {
      test('returns English translations by default', () {
        expect(appState.translate('home'), 'Home');
        expect(appState.translate('standings'), 'Standings');
        expect(appState.translate('settings'), 'Settings');
        expect(appState.translate('dark_mode'), 'Dark Mode');
      });

      test('returns Kiswahili translations', () {
        appState.setLanguage(AppLanguage.kiswahili);
        expect(appState.translate('home'), 'Nyumbani');
        expect(appState.translate('standings'), 'Msimamo');
        expect(appState.translate('settings'), 'Mipangilio');
        expect(appState.translate('dark_mode'), 'Hali ya Giza');
      });

      test('returns key as fallback for unknown key in English', () {
        expect(appState.translate('nonexistent_key'), 'nonexistent_key');
      });

      test('returns key as fallback for unknown key in Kiswahili', () {
        appState.setLanguage(AppLanguage.kiswahili);
        expect(appState.translate('nonexistent_key'), 'nonexistent_key');
      });

      test('season_underway returns dynamic season label', () {
        expect(appState.translate('season_underway'), 'Season 2026 underway');
        appState.setSeasonLabel('Championship 2026');
        expect(appState.translate('season_underway'), 'Championship 2026');
      });

      test('season_underway in Kiswahili still returns English season label (dynamic)', () {
        appState.setLanguage(AppLanguage.kiswahili);
        appState.setSeasonLabel('Season 2026');
        expect(appState.translate('season_underway'), 'Season 2026');
      });

      test('status_live translation in English', () {
        expect(appState.translate('status_live'), '● LIVE');
      });

      test('status_live translation in Kiswahili', () {
        appState.setLanguage(AppLanguage.kiswahili);
        expect(appState.translate('status_live'), '● MUBASHARA');
      });
    });
  });
}
