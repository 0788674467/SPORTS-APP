import 'package:flutter/material.dart';

/// Supported application languages.
enum AppLanguage {
  /// English language
  english,
  
  /// Kiswahili language
  kiswahili
}

/// Global application state manager for theme and localization.
class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  AppLanguage _language = AppLanguage.english;

  /// Whether dark mode is enabled
  bool get isDarkMode => _isDarkMode;
  
  /// Current application language
  AppLanguage get language => _language;

  /// Toggles dark mode on or off.
  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  /// Sets the application language.
  void setLanguage(AppLanguage language) {
    _language = language;
    notifyListeners();
  }

  /// Translates a key to the current language.
  String translate(String key) {
    final translations = _language == AppLanguage.english ? _en : _sw;
    return translations[key] ?? key;
  }

  static const Map<String, String> _en = {
    'home': 'Home',
    'standings': 'Standings',
    'talk': 'Talk',
    'more': 'More',
    'settings': 'Settings',
    'match_alerts': 'Match Alerts',
    'notifications': 'NOTIFICATIONS',
    'display': 'DISPLAY',
    'general': 'GENERAL',
    'dark_mode': 'Dark Mode',
    'language': 'Language',
    'help_center': 'Help Center',
    'about': 'About MMU Sports',
    'choose_language': 'Choose Language',
    'cancel': 'Cancel',
    'status_live': '● LIVE',
    'season_underway': 'Season 2026 underway',
    'welcome_mmu': 'Welcome to\nMMU Sports',
    'upcoming_matches': 'UPCOMING MATCHES',
    'discussions': 'Discussions',
    'fan_talk': 'Fan Talk & Match Chatter',
    'type_message': 'Type a message...',
    'choose_nickname': 'Choose a Nickname',
    'start_chatting': 'Start Chatting',
    'online': 'online',
  };

  static const Map<String, String> _sw = {
    'home': 'Nyumbani',
    'standings': 'Msimamo',
    'talk': 'Mazungumzo',
    'more': 'Zaidi',
    'settings': 'Mipangilio',
    'match_alerts': 'Arifa za Mechi',
    'notifications': 'ARIFA',
    'display': 'Onyesho',
    'general': 'JUMLA',
    'dark_mode': 'Hali ya Giza',
    'language': 'Lugha',
    'help_center': 'Kituo cha Msaada',
    'about': 'Kuhusu MMU Sports',
    'choose_language': 'Chagua Lugha',
    'cancel': 'Ghairi',
    'status_live': '● MUBASHARA',
    'season_underway': 'Simu 2026 inaendelea',
    'welcome_mmu': 'Karibu\nMMU Sports',
    'upcoming_matches': 'MECHI ZIJAZO',
    'discussions': 'Mazungumzo',
    'fan_talk': 'Mazungumzo ya Mashabiki',
    'type_message': 'Andika ujumbe...',
    'choose_nickname': 'Chagua Jina la Utani',
    'start_chatting': 'Anza Kuzungumza',
    'online': 'mtandaoni',
  };
}
