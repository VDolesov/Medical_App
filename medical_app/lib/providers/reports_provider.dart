import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'package:flutter/widgets.dart';

class Report {
  final int id;
  final String fileName;
  final DateTime createdAt;
  final int? userId;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? email;

  Report({
    required this.id,
    required this.fileName,
    required this.createdAt,
    this.userId,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    // fileName может быть int или String
    String fileName = '';
    if (json['file_name'] != null) {
      fileName = json['file_name'].toString();
    }
    // createdAt может быть строкой или int (timestamp)
    DateTime createdAt;
    if (json['created_at'] is String) {
      createdAt = DateTime.tryParse(json['created_at']) ?? DateTime.now();
    } else if (json['created_at'] is int) {
      // Если это timestamp в секундах или миллисекундах
      int ts = json['created_at'];
      if (ts > 1000000000000) {
        // миллисекунды
        createdAt = DateTime.fromMillisecondsSinceEpoch(ts);
      } else {
        // секунды
        createdAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }
    } else {
      createdAt = DateTime.now();
    }
    return Report(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      fileName: fileName,
      createdAt: createdAt,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      username: json['username']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class PatientReport {
  final String code;
  final int age;
  final List<dynamic> outOfNorms;

  PatientReport({
    required this.code,
    required this.age,
    required this.outOfNorms,
  });

  factory PatientReport.fromJson(Map<String, dynamic> json) {
    return PatientReport(
      code: json['code']?.toString() ?? '',
      age: json['age'] is int ? json['age'] : int.tryParse(json['age'].toString()) ?? 0,
      outOfNorms: json['outOfNorms'] ?? [],
    );
  }
}

class ReportsProvider with ChangeNotifier {
  static const String _baseUrl = 'https://medicalprojects-production.up.railway.app';

  List<Report> _reports = [];
  List<PatientReport> _currentReport = [];
  int _currentReportTotal = 0;
  int _currentReportPage = 1;
  int _currentReportLimit = 50;
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  // Новые поля для UI-сигналов
  bool _shouldShowReportDetails = false;
  String? _snackBarMessage;
  dynamic _reportToShow;

  // --- ADMIN ---
  List<Report> _adminReports = [];
  List<PatientReport> _adminCurrentReport = [];
  bool _adminIsLoading = false;
  String? _adminError;
  Report? _adminReportToShow;

  List<Report> get reports => _reports;
  List<PatientReport> get currentReport => _currentReport;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get shouldShowReportDetails => _shouldShowReportDetails;
  String? get snackBarMessage => _snackBarMessage;
  dynamic get reportToShow => _reportToShow;

  List<Report> get adminReports => _adminReports;
  List<PatientReport> get adminCurrentReport => _adminCurrentReport;
  bool get adminIsLoading => _adminIsLoading;
  String? get adminError => _adminError;
  Report? get adminReportToShow => _adminReportToShow;

  Future<void> loadReports(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/reports'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _reports = data.map((json) => Report.fromJson(json)).toList();
      } else {
        _error = 'Ошибка загрузки отчетов';
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReportDetails(BuildContext context, int reportId, {bool reset = true, Report? reportObject}) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    if (reset) {
      _currentReport = [];
      _currentReportPage = 1;
      _hasMore = true;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/report/$reportId?page=$_currentReportPage&limit=$_currentReportLimit'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> patients = data['patients'] ?? [];
        _currentReportTotal = data['total'] ?? 0;
        _currentReportLimit = data['limit'] ?? 50;
        _currentReportPage = data['page'] ?? 1;
        if (reset) {
          _currentReport = patients.map((json) => PatientReport.fromJson(json)).toList();
        } else {
          _currentReport.addAll(patients.map((json) => PatientReport.fromJson(json)));
        }
        _hasMore = _currentReport.length < _currentReportTotal;
        // UI сигнал: открыть модалку и показать сообщение
        if (reportObject != null) {
          showReportDetails(reportObject);
        }
        setSnackBarMessage('Детали отчёта открыты!');
      } else {
        _error = 'Ошибка загрузки деталей отчета: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Ошибка сети: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreReportDetails(BuildContext context, int reportId) async {
    if (!_hasMore || _isLoading) return;
    _currentReportPage++;
    await loadReportDetails(context, reportId, reset: false);
  }

  Future<bool> uploadFile(BuildContext context, File file) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload'),
      );

      request.headers['Authorization'] = 'Bearer ${authProvider.token}';
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Можно сохранить результат загрузки если нужно
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Ошибка загрузки файла';
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

  Future<bool> deleteReport(BuildContext context, int reportId) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/report/$reportId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _reports.removeWhere((report) => report.id == reportId);
        notifyListeners();
        return true;
      } else {
        _error = 'Ошибка удаления отчета';
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

  void clearCurrentReport() {
    _currentReport = [];
    notifyListeners();
  }

  void showReportDetails(dynamic report) {
    _shouldShowReportDetails = true;
    _reportToShow = report;
    notifyListeners();
  }

  void hideReportDetails() {
    _shouldShowReportDetails = false;
    _reportToShow = null;
    notifyListeners();
  }

  void setSnackBarMessage(String? msg) {
    _snackBarMessage = msg;
    notifyListeners();
  }

  void clearSnackBarMessage() {
    _snackBarMessage = null;
    notifyListeners();
  }

  Future<void> loadAdminReports(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;
    _adminIsLoading = true;
    _adminError = null;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/reports'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _adminReports = data.map((json) => Report.fromJson(json)).toList();
      } else {
        _adminError = 'Ошибка загрузки всех отчётов';
      }
    } catch (e) {
      _adminError = 'Ошибка сети: $e';
    } finally {
      _adminIsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminReportDetails(BuildContext context, int reportId, {Report? reportObject}) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;
    _adminCurrentReport = [];
    _adminIsLoading = true;
    _adminError = null;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/report/$reportId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> patients = data;
        if (data is Map && data.containsKey('patients')) {
          patients = data['patients'];
        }
        _adminCurrentReport = patients.map((json) => PatientReport.fromJson(json)).toList();
        if (reportObject != null) {
          _adminReportToShow = reportObject;
        }
      } else {
        _adminError = 'Ошибка загрузки деталей отчёта';
      }
    } catch (e) {
      _adminError = 'Ошибка сети: $e';
    } finally {
      _adminIsLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAdminReport(BuildContext context, int reportId) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;
    _adminIsLoading = true;
    notifyListeners();
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/admin/report/$reportId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        // После удаления обновить список
        await loadAdminReports(context);
      }
    } catch (e) {
      // Можно добавить обработку ошибок
    } finally {
      _adminIsLoading = false;
      notifyListeners();
    }
  }
} 