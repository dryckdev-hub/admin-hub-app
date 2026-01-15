import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyApiUrl = 'api_url';
  static const String _keyDbPrefix = 'db_prefix';
  static const String _keyDbSuffix = 'db_suffix';

  Future<void> saveConfig({required String url, required String prefix, required String suffix}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiUrl, url);
    await prefs.setString(_keyDbPrefix, prefix);
    await prefs.setString(_keyDbSuffix, suffix);
  }

  Future<Map<String, String>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(_keyApiUrl) ?? 'http://192.168.1.95:3000', // IP por defecto
      'prefix': prefs.getString(_keyDbPrefix) ?? '',
      'suffix': prefs.getString(_keyDbSuffix) ?? '',
    };
  }
}