// lib/providers/language_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _lang = 'en';

  String get selectedLanguage => _lang;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('recording_language') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _lang = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recording_language', code);
    notifyListeners();
  }
}
