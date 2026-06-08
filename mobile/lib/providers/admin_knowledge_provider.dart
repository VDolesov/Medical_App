import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_provider.dart';

class AdminKnowledgeProvider with ChangeNotifier {
  static const String _baseUrl = ApiConfig.baseUrl;

  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _sources = [];
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> get rules => List.unmodifiable(_rules);
  List<Map<String, dynamic>> get sources => List.unmodifiable(_sources);
  bool get loading => _loading;
  String? get error => _error;

  Map<String, String> _headers(AuthProvider auth) => {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json; charset=utf-8',
      };

  Future<void> loadAll(AuthProvider auth) async {
    if (auth.token == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rulesResp = await http.get(Uri.parse('$_baseUrl/expert/rules'), headers: _headers(auth));
      final sourcesResp = await http.get(Uri.parse('$_baseUrl/admin/expert/sources'), headers: _headers(auth));
      if (rulesResp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(rulesResp.bodyBytes));
        if (decoded is List) {
          _rules = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } else {
        _error = 'Каталог правил: HTTP ${rulesResp.statusCode}';
      }
      if (sourcesResp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(sourcesResp.bodyBytes));
        if (decoded is List) {
          _sources = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      _error = 'Ошибка загрузки: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> createRule(AuthProvider auth, Map<String, dynamic> rule) async {
    return _mutate(auth, 'POST', '$_baseUrl/admin/expert/rules', rule);
  }

  Future<String?> updateRule(AuthProvider auth, int id, Map<String, dynamic> rule) async {
    return _mutate(auth, 'PUT', '$_baseUrl/admin/expert/rules/$id', rule);
  }

  Future<String?> toggleRule(AuthProvider auth, int id, bool active) async {
    return _mutate(auth, 'POST', '$_baseUrl/admin/expert/rules/$id/toggle', {'active': active});
  }

  Future<String?> deleteRule(AuthProvider auth, int id) async {
    return _mutate(auth, 'DELETE', '$_baseUrl/admin/expert/rules/$id', null);
  }

  Future<String?> createSource(AuthProvider auth, Map<String, dynamic> source) async {
    return _mutate(auth, 'POST', '$_baseUrl/admin/expert/sources', source);
  }

  Future<String?> updateSource(AuthProvider auth, int id, Map<String, dynamic> source) async {
    return _mutate(auth, 'PUT', '$_baseUrl/admin/expert/sources/$id', source);
  }

  Future<String?> _mutate(AuthProvider auth, String method, String url, Map<String, dynamic>? body) async {
    if (auth.token == null) return 'Нет авторизации';
    try {
      final encoded = body == null ? null : json.encode(body);
      final headers = _headers(auth);
      http.Response resp;
      switch (method) {
        case 'POST':
          resp = await http.post(Uri.parse(url), headers: headers, body: encoded);
          break;
        case 'PUT':
          resp = await http.put(Uri.parse(url), headers: headers, body: encoded);
          break;
        case 'DELETE':
          resp = await http.delete(Uri.parse(url), headers: headers);
          break;
        default:
          return 'Неизвестный метод $method';
      }
      if (resp.statusCode == 200) {
        await loadAll(auth);
        return null;
      }
      try {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
      return 'HTTP ${resp.statusCode}';
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  void clear() {
    _rules = [];
    _sources = [];
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
