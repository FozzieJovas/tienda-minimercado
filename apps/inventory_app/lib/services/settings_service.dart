import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _serverUrlKey = 'server_url';
  static const defaultServerUrl = 'http://tienda.local:4000';

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? defaultServerUrl;
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }
}
