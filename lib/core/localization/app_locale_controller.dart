import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLanguageStorageKey = 'app_selected_language';

/// Manages application-wide active locale, reactive switching, and persistent storage.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier([super.initialLocale = const Locale('ar', 'EG')]) {
    _loadSavedLocale();
  }

  /// Loads saved language code from local storage on app launch if not already initialized.
  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kLanguageStorageKey);
      if (savedCode != null) {
        final newLocale = savedCode == 'en'
            ? const Locale('en', 'US')
            : const Locale('ar', 'EG');
        if (state != newLocale) {
          state = newLocale;
        }
      }
    } catch (e) {
      developer.log('LocaleNotifier._loadSavedLocale error: $e');
    }
  }

  /// Changes language, instantly updating UI direction and strings across the entire app.
  Future<void> setLocale(String languageCode) async {
    final newLocale = languageCode == 'en'
        ? const Locale('en', 'US')
        : const Locale('ar', 'EG');

    if (state == newLocale) return;

    state = newLocale;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguageStorageKey, languageCode);
    } catch (e) {
      developer.log('LocaleNotifier.setLocale persistence error: $e');
    }
  }

  bool get isArabic => state.languageCode == 'ar';
  bool get isEnglish => state.languageCode == 'en';
}

/// Riverpod provider for active [Locale].
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Convenience provider for checking if current locale is Arabic (RTL).
final isArabicProvider = Provider<bool>((ref) {
  return ref.watch(localeProvider).languageCode == 'ar';
});
