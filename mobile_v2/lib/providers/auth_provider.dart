import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

class AppUser {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final String? email;
  final int? patientId;
  final String? patientCode;

  AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.email,
    this.patientId,
    this.patientCode,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        username: json['username']?.toString() ?? '',
        firstName: json['first_name']?.toString() ?? '',
        lastName: json['last_name']?.toString() ?? '',
        role: json['role']?.toString() ?? 'patient',
        email: json['email']?.toString(),
        patientId: (json['patient_id'] as num?)?.toInt(),
        patientCode: json['patient_code']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'email': email,
        'patient_id': patientId,
        'patient_code': patientCode,
      };

  String get displayName {
    final full = ('$lastName $firstName').trim();
    return full.isEmpty ? username : full;
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isDoctor => role.toLowerCase() == 'doctor';
  bool get isPatient => role.toLowerCase() == 'patient';
}

class AuthProvider with ChangeNotifier {
  final ApiClient _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppUser? _user;
  String? _token;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api) {
    _api.onUnauthorized = _onUnauthorized;
    _restore();
  }

  void _onUnauthorized() {
    if (_token == null && _user == null) return;
    _user = null;
    _token = null;
    _storage.delete(key: 'auth_token');
    _storage.delete(key: 'user_data');
    notifyListeners();
  }

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _loading;
  bool get isLoggedIn => _token != null && _user != null;
  String? get lastError => _error;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isDoctor => _user?.isDoctor ?? false;
  bool get isPatient => _user?.isPatient ?? false;

  Future<void> _restore() async {
    try {
      final t = await _storage.read(key: 'auth_token');
      final u = await _storage.read(key: 'user_data');
      if (t != null && u != null) {
        _token = t;
        _user = AppUser.fromJson(json.decode(u));
        _api.setToken(t);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('auth restore: $e');
    }
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _api.post('/login', {'username': username, 'password': password});
      if (!r.ok) {
        _error = r.errorMessage ?? 'Не удалось войти';
        return false;
      }
      final map = r.asMap();
      _token = map['token'] as String?;
      final userMap = map['user'];
      if (_token == null || userMap is! Map) {
        _error = 'Некорректный ответ сервера';
        return false;
      }
      _user = AppUser.fromJson(Map<String, dynamic>.from(userMap));
      _api.setToken(_token);
      await _storage.write(key: 'auth_token', value: _token);
      await _storage.write(key: 'user_data', value: json.encode(_user!.toJson()));
      return true;
    } catch (e) {
      _error = 'Ошибка сети: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    String? adminSecret,
    int? patientAge,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'username': username,
        'password': password,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        if (adminSecret != null && adminSecret.isNotEmpty) 'adminSecret': adminSecret,
        if (patientAge != null) 'patientAge': patientAge,
      };
      final r = await _api.post('/register', body);
      if (!r.ok) {
        _error = r.errorMessage ?? 'Не удалось зарегистрироваться';
        return null;
      }
      return r.asMap()['patient_code']?.toString();
    } catch (e) {
      _error = 'Ошибка сети: $e';
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _api.setToken(null);
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    notifyListeners();
  }
}
