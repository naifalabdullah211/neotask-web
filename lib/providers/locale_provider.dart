import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns NeoTask's UI language and persists it separately for every account.
///
/// Before sign-in, the guest preference is used by the authentication screens.
/// After sign-in, [bindUser] switches to the preference stored for that uid.
class LocaleProvider extends ChangeNotifier {
  static const _guestKey = 'neotask_locale_guest';

  Locale _locale = const Locale('ar');
  String? _boundUserId;
  int _loadGeneration = 0;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isArabic => languageCode == 'ar';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _applyCode(prefs.getString(_guestKey) ?? 'ar');
  }

  void bindUser(String? userId) {
    if (_boundUserId == userId) return;
    _boundUserId = userId;
    final generation = ++_loadGeneration;
    unawaited(_loadForBinding(userId, generation));
  }

  Future<void> _loadForBinding(String? userId, int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (generation != _loadGeneration) return;
    final key = userId == null ? _guestKey : _userKey(userId);
    final saved = prefs.getString(key);
    _applyCode(saved ?? 'ar');
  }

  Future<void> setLanguage(String languageCode) async {
    final normalized = languageCode == 'en' ? 'en' : 'ar';
    _applyCode(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _boundUserId == null ? _guestKey : _userKey(_boundUserId!),
      normalized,
    );
  }

  Future<void> toggle() => setLanguage(isArabic ? 'en' : 'ar');

  void _applyCode(String code) {
    final next = Locale(code == 'en' ? 'en' : 'ar');
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
  }

  static String _userKey(String uid) => 'neotask_locale_user_$uid';
}
