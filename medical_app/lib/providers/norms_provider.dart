import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'package:flutter/material.dart';

class Norm {
  final int id;
  final String name;
  final double minValue;
  final double maxValue;
  final String unit;

  Norm({
    required this.id,
    required this.name,
    required this.minValue,
    required this.maxValue,
    required this.unit,
  });

  factory Norm.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    return Norm(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      minValue: parseDouble(json['min_value']),
      maxValue: parseDouble(json['max_value']),
      unit: json['unit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'min_value': minValue,
      'max_value': maxValue,
      'unit': unit,
    };
  }
}

class NormsProvider with ChangeNotifier {
  static const String _baseUrl = 'http://10.0.2.2:5000';

  List<Norm> _norms = [];
  bool _isLoading = false;
  String? _error;

  List<Norm> get norms => _norms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNorms(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/norms'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Debug: Norms API response status: ${response.statusCode}');
        print('Debug: Norms API response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (kDebugMode) {
          print('Debug: Parsed norms data: $data');
        }
        _norms = data.map((json) => Norm.fromJson(json)).toList();
        if (kDebugMode) {
          print('Debug: Created norms objects: ${_norms.length}');
          for (var norm in _norms) {
            print('Debug: Norm - ID: ${norm.id}, Name: ${norm.name}, Min: ${norm.minValue}, Max: ${norm.maxValue}, Unit: ${norm.unit}');
          }
        }
      } else {
        _error = 'Ошибка загрузки норм: ${response.statusCode}';
        if (kDebugMode) {
          print('Debug: Norms API error: ${response.body}');
        }
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
      if (kDebugMode) {
        print('Debug: Norms API exception: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addNorm(BuildContext context, Norm norm) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || !authProvider.isAdmin) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/norms'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': norm.name,
          'min_value': norm.minValue,
          'max_value': norm.maxValue,
          'unit': norm.unit,
        }),
      );

      if (response.statusCode == 200) {
        await loadNorms(context);
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Ошибка добавления нормы';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateNorm(BuildContext context, Norm norm) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || !authProvider.isAdmin) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/norms/${norm.id}'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': norm.name,
          'min_value': norm.minValue,
          'max_value': norm.maxValue,
          'unit': norm.unit,
        }),
      );

      if (response.statusCode == 200) {
        await loadNorms(context);
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Ошибка обновления нормы';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteNorm(BuildContext context, int normId) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || !authProvider.isAdmin) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/norms/$normId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _norms.removeWhere((norm) => norm.id == normId);
        notifyListeners();
        return true;
      } else {
        _error = 'Ошибка удаления нормы';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 