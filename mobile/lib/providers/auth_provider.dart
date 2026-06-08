import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

class User {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final String? email;
  final int? patientId;
  final String? patientCode;

  User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.email,
    this.patientId,
    this.patientCode,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final pid = json['patient_id'];
    return User(
      id: json['id'],
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      role: json['role'],
      email: json['email'] as String?,
      patientId: pid == null ? null : (pid is int ? pid : int.tryParse(pid.toString())),
      patientCode: json['patient_code'] as String?,
    );
  }
}

class AuthProvider with ChangeNotifier {
  static const String _baseUrl = ApiConfig.baseUrl;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _user;
  String? _token;
  bool _isLoading = false;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isAdmin => _user?.role == 'admin';
  bool get isPatient => _user?.role == 'patient';
  bool get isDoctor => _user?.role == 'doctor';

  AuthProvider() {
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    try {
      final storedToken = await _storage.read(key: 'auth_token');
      final storedUser = await _storage.read(key: 'user_data');

      if (storedToken != null && storedUser != null) {
        _token = storedToken;
        _user = User.fromJson(json.decode(storedUser));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки сохраненной аутентификации: $e');
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = User.fromJson(data['user']);
        await _storage.write(key: 'auth_token', value: _token);
        await _storage.write(key: 'user_data', value: json.encode(data['user']));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Ошибка входа');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
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
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> body = {
        'username': username,
        'password': password,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
      };

      if (role == 'admin' && adminSecret != null) {
        body['adminSecret'] = adminSecret;
      }
      if (role == 'patient' && patientAge != null) {
        body['patientAge'] = patientAge;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['patient_code'] as String?;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Ошибка регистрации');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;

    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');

    notifyListeners();
  }

  Future<User?> getCurrentUser() async {
    if (_token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _user = User.fromJson(userData);
        notifyListeners();
        return _user;
      }
    } catch (e) {
      debugPrint('Ошибка получения данных пользователя: $e');
    }

    return null;
  }
}
