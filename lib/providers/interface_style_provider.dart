import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

enum InterfaceStyle { classic, modern }

class InterfaceStyleProvider extends ChangeNotifier {
  static const _prefKey = 'neotask_interface_style';

  InterfaceStyle _style = InterfaceStyle.modern;
  InterfaceStyle get style => _style;
  bool get isModern => _style == InterfaceStyle.modern;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _style = saved == InterfaceStyle.classic.name
        ? InterfaceStyle.classic
        : InterfaceStyle.modern;
    notifyListeners();
  }

  Future<void> toggle() async {
    _style = isModern ? InterfaceStyle.classic : InterfaceStyle.modern;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _style.name);
    notifyListeners();
  }

  ThemeData get theme => isModern ? modernTheme : AppTheme.lightTheme;

  static ThemeData get modernTheme {
    const navy = Color(0xFF1B3A6B);
    const mint = Color(0xFF33D6A6);
    const gold = Color(0xFFE8B84B);
    const background = Color(0xFFF4F7FB);
    const text = Color(0xFF16243A);

    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      primary: navy,
      secondary: mint,
      tertiary: gold,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: mint.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? navy : const Color(0xFF64748B),
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? navy : const Color(0xFF64748B),
        )),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: navy,
        unselectedItemColor: Color(0xFF64748B),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mint,
        foregroundColor: navy,
        elevation: 5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: navy, width: 2),
        ),
      ),
      dividerColor: const Color(0xFFE2E8F0),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: text, fontWeight: FontWeight.w900),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: mint.withValues(alpha: 0.22),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
    );
  }
}
