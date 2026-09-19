import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _serverUrlKey = 'server_url';
  static const _printerMacKey = 'printer_mac';
  static const defaultServerUrl = 'http://tienda.local:4000';

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? defaultServerUrl;
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  Future<String?> getPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerMacKey);
  }

  Future<void> setPrinterMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerMacKey, mac);
  }
}
