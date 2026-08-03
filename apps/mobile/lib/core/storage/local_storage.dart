import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static const String _settingsBoxName = 'settings';
  static const String _cacheBoxName = 'cache';

  late final Box _settingsBox;
  late final Box _cacheBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _cacheBox = await Hive.openBox(_cacheBoxName);
  }

  // General Settings (Theme, User Profile Details, Session Settings)
  Future<void> writeSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic readSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }

  // Local Cache (Search results, offline listings, metadata) with TTL
  Future<void> cacheData(String key, dynamic data, {Duration? ttl}) async {
    final entry = {
      'data': data,
      'expiry': ttl != null
          ? DateTime.now().add(ttl).millisecondsSinceEpoch
          : null,
    };
    await _cacheBox.put(key, entry);
  }

  dynamic getCachedData(String key) {
    final entry = _cacheBox.get(key);
    if (entry == null) return null;

    final expiry = entry['expiry'] as int?;
    if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
      _cacheBox.delete(key);
      return null;
    }
    return entry['data'];
  }

  Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  Future<void> clearAll() async {
    await _settingsBox.clear();
    await _cacheBox.clear();
  }
}
