import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _enableNotifications = true;
  double _textScaleFactor = 1.0; // Default font size

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get enableNotifications => _enableNotifications;
  double get textScaleFactor => _textScaleFactor;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool('is_dark_mode') ?? false;
    _enableNotifications = prefs.getBool('enable_notifications') ?? true;
    _textScaleFactor = prefs.getDouble('text_scale_factor') ?? 1.0;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); 

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);

    _syncToBackend({'is_dark_mode': isDark});
  }

  Future<void> toggleNotifications(bool isEnabled) async {
    _enableNotifications = isEnabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_notifications', isEnabled);

    _syncToBackend({'enable_notifications': isEnabled});
  }

  /// Set text scale factor (0.8 to 1.5)
  Future<void> setTextScaleFactor(double scale) async {
    // Clamp between 0.8 and 1.5
    _textScaleFactor = scale.clamp(0.8, 1.5);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale_factor', _textScaleFactor);

    _syncToBackend({'text_scale_factor': _textScaleFactor});
  }

  Future<void> _syncToBackend(Map<String, dynamic> data) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      if (token == null) return;

      final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
      await dio.patch(
        '/api/user/profile',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // Silent fail - settings already saved locally
      debugPrint('⚠️ Failed to sync settings to backend: $e');
    }
  }
}