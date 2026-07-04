import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  String? _token;
  void Function()? onUnauthorized;

  void setToken(String? token) => _token = token;

  Map<String, String> _headers() => {
        if (_token != null) 'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  ApiResponse _handle(http.Response r) {
    final resp = ApiResponse._fromHttp(r);
    if (resp.statusCode == 401 && _token != null) {
      _token = null;
      onUnauthorized?.call();
    }
    return resp;
  }

  Future<ApiResponse> get(String path) async {
    final r = await http.get(_uri(path), headers: _headers());
    return _handle(r);
  }

  Future<ApiResponse> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(_uri(path), headers: _headers(), body: body == null ? null : json.encode(body));
    return _handle(r);
  }

  Future<ApiResponse> put(String path, [Map<String, dynamic>? body]) async {
    final r = await http.put(_uri(path), headers: _headers(), body: body == null ? null : json.encode(body));
    return _handle(r);
  }

  Future<ApiResponse> delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers());
    return _handle(r);
  }
}

class ApiResponse {
  final int statusCode;
  final dynamic body;
  final String rawText;

  ApiResponse._(this.statusCode, this.body, this.rawText);

  factory ApiResponse._fromHttp(http.Response r) {
    String text;
    try {
      text = utf8.decode(r.bodyBytes);
    } catch (_) {
      text = r.body;
    }
    dynamic decoded;
    try {
      decoded = text.isEmpty ? null : json.decode(text);
    } catch (_) {
      decoded = null;
    }
    return ApiResponse._(r.statusCode, decoded, text);
  }

  bool get ok => statusCode >= 200 && statusCode < 300;

  String? get errorMessage {
    if (ok) return null;
    if (body is Map && body['error'] != null) return body['error'].toString();
    if (rawText.isNotEmpty && rawText.length < 256) return rawText;
    return 'HTTP $statusCode';
  }

  List<dynamic> asList({String? wrapperKey}) {
    final b = body;
    if (b is List) return b;
    if (b is Map) {
      if (wrapperKey != null && b[wrapperKey] is List) return b[wrapperKey] as List;
      for (final k in const ['items', 'content', 'reports', 'patients', 'data']) {
        if (b[k] is List) return b[k] as List;
      }
    }
    return const [];
  }

  Map<String, dynamic> asMap() {
    final b = body;
    if (b is Map) return Map<String, dynamic>.from(b);
    return const {};
  }
}
