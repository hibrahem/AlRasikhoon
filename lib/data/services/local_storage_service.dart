import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // User data
  Future<void> setUserId(String userId) async {
    await _prefs.setString(AppConstants.keyUserId, userId);
  }

  String? getUserId() {
    return _prefs.getString(AppConstants.keyUserId);
  }

  Future<void> setUserRole(String role) async {
    await _prefs.setString(AppConstants.keyUserRole, role);
  }

  String? getUserRole() {
    return _prefs.getString(AppConstants.keyUserRole);
  }

  // Language
  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(AppConstants.keyLanguage, languageCode);
  }

  String getLanguage() {
    return _prefs.getString(AppConstants.keyLanguage) ?? 'ar';
  }

  // Theme
  Future<void> setTheme(String theme) async {
    await _prefs.setString(AppConstants.keyTheme, theme);
  }

  String getTheme() {
    return _prefs.getString(AppConstants.keyTheme) ?? 'light';
  }

  // First launch
  Future<void> setFirstLaunch(bool isFirstLaunch) async {
    await _prefs.setBool(AppConstants.keyFirstLaunch, isFirstLaunch);
  }

  bool isFirstLaunch() {
    return _prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
  }

  // Clear all
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  // Pending sign-in email (for email link auth)
  Future<void> setPendingSignInEmail(String email) async {
    await _prefs.setString(AppConstants.keyPendingSignInEmail, email);
  }

  String? getPendingSignInEmail() {
    return _prefs.getString(AppConstants.keyPendingSignInEmail);
  }

  Future<void> clearPendingSignInEmail() async {
    await _prefs.remove(AppConstants.keyPendingSignInEmail);
  }

  // Clear user data (on logout)
  Future<void> clearUserData() async {
    await _prefs.remove(AppConstants.keyUserId);
    await _prefs.remove(AppConstants.keyUserRole);
    await _prefs.remove(AppConstants.keyPendingSignInEmail);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorageService(prefs);
});
