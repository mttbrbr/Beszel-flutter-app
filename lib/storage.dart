import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';

class Session {
  final String url, email, password;
  final String? token;
  Session(this.url, this.email, this.password, this.token);
}

class Store {
  static const _secure = FlutterSecureStorage();

  static Future<void> saveSession(String url, String email, String password, String token) async {
    await _secure.write(key: 'url', value: url);
    await _secure.write(key: 'email', value: email);
    await _secure.write(key: 'password', value: password);
    await _secure.write(key: 'token', value: token);
  }

  static Future<Session?> session() async {
    try {
      return await _readSession();
    } catch (_) {
      // Undecryptable data (e.g. restored backup / reinstall): start clean.
      await _secure.deleteAll();
      return null;
    }
  }

  static Future<Session?> _readSession() async {
    final url = await _secure.read(key: 'url');
    final email = await _secure.read(key: 'email');
    final pw = await _secure.read(key: 'password');
    if (url == null || email == null || pw == null) return null;
    return Session(url, email, pw, await _secure.read(key: 'token'));
  }

  static Future<void> logout() async {
    await _secure.deleteAll();
    final p = await SharedPreferences.getInstance();
    await p.remove('rules');
    await p.remove('active');
  }

  /// Returns an authenticated API, re-logging in if needed.
  static Future<BeszelApi?> api({bool forceLogin = false}) async {
    final s = await session();
    if (s == null) return null;
    final api = BeszelApi(s.url, token: forceLogin ? null : s.token);
    if (api.token == null) {
      final t = await api.login(s.email, s.password);
      await _secure.write(key: 'token', value: t);
    }
    return api;
  }

  static Future<Map<String, AlertRules>> rules() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final raw = p.getString('rules');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, AlertRules.fromJson(Map<String, dynamic>.from(v))));
  }

  static Future<void> saveRules(Map<String, AlertRules> rules) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('rules', jsonEncode(rules.map((k, v) => MapEntry(k, v.toJson()))));
  }

  static Future<Set<String>> active() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return (p.getStringList('active') ?? []).toSet();
  }

  static Future<void> saveActive(Set<String> a) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('active', a.toList());
  }

  static Future<ThemeMode> themeMode() async {
    final p = await SharedPreferences.getInstance();
    return ThemeMode.values.byName(p.getString('theme') ?? 'dark');
  }

  static Future<void> saveThemeMode(ThemeMode m) async =>
      (await SharedPreferences.getInstance()).setString('theme', m.name);

  static Future<StatRange> range() async {
    final p = await SharedPreferences.getInstance();
    return StatRange.values.byName(p.getString('range') ?? 'h1');
  }

  static Future<void> saveRange(StatRange r) async =>
      (await SharedPreferences.getInstance()).setString('range', r.name);
}
