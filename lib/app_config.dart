/// Centralized configuration file for the APEPS Flutter App.
/// Switch between local development and production easily.
class AppConfig {
  /// Toggle this to:
  /// - `true` to load the local development server (http://localhost:5177)
  /// - `false` to load production (https://hiralal-dev.anugatai.com)
  static const bool useLocalUrl = false;

  // ─────────────────────────────────────────────────────────────────────────────
  // URLs Configuration
  // ─────────────────────────────────────────────────────────────────────────────

  /// Local Vite Dev Server URL
  ///
  /// IMPORTANT FOR PHYSICAL ANDROID DEVICES (Connected via USB):
  /// Run this one-time command in your terminal so "localhost" on your phone
  /// routes to your computer's Vite server:
  ///
  ///   adb reverse tcp:5177 tcp:5177
  ///   adb reverse tcp:8000 tcp:8000
  ///
  /// If you are using the Android Emulator (without adb reverse), you can use:
  ///   "http://10.0.2.2:5177"
  static const String devWebUrl = "http://localhost:5177";

  /// Production Web URL
  static const String prodWebUrl = "https://hiralal-dev.anugatai.com";

  /// Local Gateway / Backend API URL
  static const String devApiUrl = "http://localhost:8000";

  /// Production Gateway / Backend API URL
  static const String prodApiUrl = "https://api.calmchase.com";

  // ─────────────────────────────────────────────────────────────────────────────
  // Getters & Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Active web app URL loaded inside the app
  static String get webUrl => useLocalUrl ? devWebUrl : prodWebUrl;

  /// Active backend API URL
  static String get apiUrl => useLocalUrl ? devApiUrl : prodApiUrl;

  /// Returns whether a given URL belongs to our app domains (local or production).
  /// Used to automatically close authentication/payment modal bottom sheets on redirect.
  static bool isAppDomain(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '10.0.2.2' ||
        host == '127.0.0.1' ||
        host.contains('anugatai.com') ||
        host.contains('calmchase.com') ||
        url.contains('localhost:5177');
  }
}
