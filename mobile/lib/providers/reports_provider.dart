import 'dart:convert';
import 'dart:io';
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
    String fileName = '';
    if (json['file_name'] != null) {
      fileName = json['file_name'].toString();
    }
    DateTime createdAt;
    if (json['created_at'] is String) {
      createdAt = DateTime.tryParse(json['created_at']) ?? DateTime.now();
    } else if (json['created_at'] is int) {
      int ts = json['created_at'];
      if (ts > 1000000000000) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(ts);
      } else {
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

class BindingPickerPatient {
  final int id;
  final String code;
  final int? age;
  final String? gender;
  final String? viewerStatus;
  final String? attendingDoctorLabel;
  final bool hasAppAccount;
  final String? lkUserName;

  BindingPickerPatient({
    required this.id,
    required this.code,
    this.age,
    this.gender,
    this.viewerStatus,
    this.attendingDoctorLabel,
    this.hasAppAccount = false,
    this.lkUserName,
  });

  factory BindingPickerPatient.fromDoctorDirectory(Map<String, dynamic> json) {
    return BindingPickerPatient(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      code: json['code']?.toString() ?? '',
      age: json['age'] is int ? json['age'] as int : int.tryParse(json['age']?.toString() ?? ''),
      gender: json['gender']?.toString(),
      viewerStatus: json['viewer_status']?.toString(),
      attendingDoctorLabel: json['attending_doctor_label']?.toString(),
      hasAppAccount: json['has_app_account'] == true,
      lkUserName: json['lk_user_name']?.toString(),
    );
  }

  factory BindingPickerPatient.fromAdminDirectory(Map<String, dynamic> json) {
    return BindingPickerPatient(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      code: json['code']?.toString() ?? '',
      age: json['age'] is int ? json['age'] as int : int.tryParse(json['age']?.toString() ?? ''),
      gender: json['gender']?.toString(),
      viewerStatus: null,
      attendingDoctorLabel: json['attending_doctor_label']?.toString(),
      hasAppAccount: json['has_app_account'] == true,
      lkUserName: json['lk_user_name']?.toString(),
    );
  }

  String get listTileSubtitle {
    final line1 = <String>[];
    if (age != null) line1.add('$age лет');
    if (gender != null && gender!.isNotEmpty) line1.add(gender!);
    if (lkUserName != null && lkUserName!.trim().isNotEmpty) {
      line1.add('в ЛК: ${lkUserName!.trim()}');
    }
    if (!hasAppAccount) line1.add('нет аккаунта в ЛК');

    final line2 = <String>[];
    if (viewerStatus == 'free') line2.add('закрепление: свободен');
    if (viewerStatus == 'mine') line2.add('закрепление: ваш пациент');
    if (attendingDoctorLabel != null && attendingDoctorLabel!.isNotEmpty) {
      line2.add('врач в карточке: $attendingDoctorLabel');
    }

    final a = line1.join(' · ');
    final b = line2.join(' · ');
    if (a.isEmpty && b.isEmpty) return code;
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    return '$a\n$b';
  }

  String get choiceSubtitle {
    final parts = <String>[];
    if (lkUserName != null && lkUserName!.trim().isNotEmpty) {
      parts.add(lkUserName!.trim());
    }
    if (age != null) parts.add('$age лет');
    if (gender != null && gender!.isNotEmpty) parts.add(gender!);
    if (viewerStatus == 'free') {
      parts.add('свободен');
    } else if (viewerStatus == 'mine') {
      parts.add('ваш пациент');
    }
    if (attendingDoctorLabel != null && attendingDoctorLabel!.isNotEmpty) {
      parts.add('врач: $attendingDoctorLabel');
    }
    if (parts.isEmpty) return hasAppAccount ? 'есть ЛК' : code;
    return parts.join(' · ');
  }
}

class PatientReport {
  final String code;
  final int age;
  final List<dynamic> outOfNorms;
  final int? rowIndex;
  final String? linkStatus;
  final String? linkCode;
  final int? linkPatientId;
  final String? attendingDoctorLabel;
  final String? reportUploadedByLabel;
  final bool linkLockedForMe;
  final bool canAttach;
  final bool canDetach;

  PatientReport({
    required this.code,
    required this.age,
    required this.outOfNorms,
    this.rowIndex,
    this.linkStatus,
    this.linkCode,
    this.linkPatientId,
    this.attendingDoctorLabel,
    this.reportUploadedByLabel,
    this.linkLockedForMe = false,
    this.canAttach = true,
    this.canDetach = false,
  });

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static bool _bool(dynamic v, [bool d = false]) {
    if (v is bool) return v;
    return d;
  }

  factory PatientReport.fromJson(Map<String, dynamic> json) {
    final norms = json['outOfNorms'] ?? json['out_of_norms'];
    return PatientReport(
      code: json['code']?.toString() ?? '',
      age: json['age'] is int ? json['age'] as int : int.tryParse(json['age']?.toString() ?? '') ?? 0,
      outOfNorms: norms is List ? norms : [],
      rowIndex: _int(json['row_index']),
      linkStatus: json['link_status']?.toString(),
      linkCode: json['link_code']?.toString(),
      linkPatientId: _int(json['link_patient_id']),
      attendingDoctorLabel: json['attending_doctor_label']?.toString(),
      reportUploadedByLabel: json['report_uploaded_by_label']?.toString(),
      linkLockedForMe: _bool(json['link_locked_for_me']),
      canAttach: _bool(json['can_attach'], true),
      canDetach: _bool(json['can_detach']),
    );
  }
}

class ReportsProvider with ChangeNotifier {
  static const String _baseUrl = 'http://10.0.2.2:8080';

  List<Report> _reports = [];
  List<PatientReport> _currentReport = [];
  int _currentReportTotal = 0;
  int _currentReportPage = 1;
  int _currentReportLimit = 50;
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  bool _shouldShowReportDetails = false;
  String? _snackBarMessage;
  dynamic _reportToShow;

  List<Map<String, dynamic>> _analyticsPatients = [];
  bool _analyticsLoading = false;
  bool _analyticsGenerating = false;
  String? _analyticsError;
  int? _analyticsReportId;

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

  List<Map<String, dynamic>> get analyticsPatients => _analyticsPatients;
  bool get analyticsLoading => _analyticsLoading;
  bool get analyticsGenerating => _analyticsGenerating;
  String? get analyticsError => _analyticsError;
  int? get analyticsReportId => _analyticsReportId;

  List<PatientReport> _bindingRows = [];
  bool _bindingLoading = false;
  String? _bindingError;
  int? _bindingReportId;
  int? _bindingReportTotal;

  List<BindingPickerPatient> _bindingPickerPatients = [];
  bool _bindingPickerLoading = false;
  String? _bindingPickerError;

  List<PatientReport> get bindingRows => _bindingRows;
  bool get bindingLoading => _bindingLoading;
  String? get bindingError => _bindingError;
  int? get bindingReportId => _bindingReportId;
  int? get bindingReportTotal => _bindingReportTotal;

  List<BindingPickerPatient> get bindingPickerPatients => _bindingPickerPatients;
  bool get bindingPickerLoading => _bindingPickerLoading;
  String? get bindingPickerError => _bindingPickerError;

  Future<void> loadReportRowsForBinding(BuildContext context, int reportId, {required bool isAdmin}) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    _bindingReportId = reportId;
    _bindingLoading = true;
    _bindingError = null;
    notifyListeners();

    try {
      final path = isAdmin
          ? '$_baseUrl/admin/report/$reportId?page=1&limit=500'
          : '$_baseUrl/report/$reportId?page=1&limit=500';
      final response = await http.get(
        Uri.parse(path),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final t = data['total'];
          _bindingReportTotal = t is int ? t : int.tryParse(t?.toString() ?? '');
        } else {
          _bindingReportTotal = null;
        }
        List<dynamic> patients;
        if (data is Map && data.containsKey('patients')) {
          patients = data['patients'] as List<dynamic>;
        } else if (data is List) {
          patients = data;
        } else {
          patients = [];
        }
        _bindingRows = patients
            .map((e) => PatientReport.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        _bindingError = 'Ошибка загрузки строк отчёта';
        _bindingRows = [];
      }
    } catch (e) {
      _bindingError = 'Ошибка сети: $e';
      _bindingRows = [];
    } finally {
      _bindingLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBindingPickerPatients(
    BuildContext context, {
    required bool isAdmin,
    String query = '',
  }) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    _bindingPickerLoading = true;
    _bindingPickerError = null;
    notifyListeners();

    try {
      final qp = <String, String>{
        'page': '0',
        'size': '100',
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'registered_only': 'true',
      };
      final headers = <String, String>{
        'Authorization': 'Bearer ${authProvider.token}',
        'Content-Type': 'application/json',
      };
      Uri patientsUri(bool reg) {
        final q = Map<String, String>.from(qp)..['registered_only'] = reg ? 'true' : 'false';
        return isAdmin
            ? Uri.parse('$_baseUrl/admin/patients').replace(queryParameters: q)
            : Uri.parse('$_baseUrl/doctor/patients').replace(queryParameters: q);
      }

      var response = await http.get(patientsUri(true), headers: headers);
      var filterLkOnClient = false;
      if (response.statusCode != 200) {
        response = await http.get(patientsUri(false), headers: headers);
        filterLkOnClient = true;
      }

      if (response.statusCode != 200) {
        _bindingPickerError =
            'Не удалось загрузить список пациентов (HTTP ${response.statusCode})';
        _bindingPickerPatients = [];
        return;
      }

      final body = json.decode(response.body);
      final List<dynamic> content;
      if (body is Map && body['content'] is List) {
        content = body['content'] as List<dynamic>;
      } else {
        content = [];
      }

      if (isAdmin) {
        _bindingPickerPatients = content
            .map((e) => BindingPickerPatient.fromAdminDirectory(Map<String, dynamic>.from(e as Map)))
            .where((p) {
              if (p.code.isEmpty) return false;
              if (filterLkOnClient && !p.hasAppAccount) return false;
              return true;
            })
            .toList()
          ..sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
      } else {
        _bindingPickerPatients = content
            .map((e) => BindingPickerPatient.fromDoctorDirectory(Map<String, dynamic>.from(e as Map)))
            .where((p) {
              final s = p.viewerStatus ?? '';
              if (p.code.isEmpty || (s != 'free' && s != 'mine')) return false;
              if (filterLkOnClient && !p.hasAppAccount) return false;
              return true;
            })
            .toList()
          ..sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
      }
    } catch (e) {
      _bindingPickerError = 'Ошибка сети: $e';
      _bindingPickerPatients = [];
    } finally {
      _bindingPickerLoading = false;
      notifyListeners();
    }
  }

  Future<String?> attachPatientToRow(
    BuildContext context, {
    required int reportId,
    required int rowIndex,
    required String patientCode,
    required bool isAdmin,
  }) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return 'Нет авторизации';

    final base = isAdmin
        ? '$_baseUrl/admin/reports/$reportId/rows/$rowIndex/patient'
        : '$_baseUrl/doctor/reports/$reportId/rows/$rowIndex/patient';

    try {
      final response = await http.put(
        Uri.parse(base),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'patient_code': patientCode.trim()}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadReportRowsForBinding(context, reportId, isAdmin: isAdmin);
        await loadBindingPickerPatients(context, isAdmin: isAdmin);
        return null;
      }
      final err = _parseErrorBody(response.body);
      return err ?? 'Код ${response.statusCode}';
    } catch (e) {
      return 'Ошибка сети: $e';
    }
  }

  Future<String?> detachPatientFromRow(
    BuildContext context, {
    required int reportId,
    required int rowIndex,
    required bool isAdmin,
  }) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return 'Нет авторизации';

    final base = isAdmin
        ? '$_baseUrl/admin/reports/$reportId/rows/$rowIndex/patient'
        : '$_baseUrl/doctor/reports/$reportId/rows/$rowIndex/patient';

    try {
      final response = await http.delete(
        Uri.parse(base),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadReportRowsForBinding(context, reportId, isAdmin: isAdmin);
        await loadBindingPickerPatients(context, isAdmin: isAdmin);
        return null;
      }
      final err = _parseErrorBody(response.body);
      return err ?? 'Код ${response.statusCode}';
    } catch (e) {
      return 'Ошибка сети: $e';
    }
  }

  String? _parseErrorBody(String body) {
    try {
      final m = json.decode(body);
      if (m is Map && m['message'] != null) return m['message'].toString();
      if (m is Map && m['error'] != null) return m['error'].toString();
    } catch (_) {}
    return null;
  }

  Future<void> loadReports(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final path = authProvider.isPatient ? '/patient/reports' : '/reports';
      final response = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final list = _extractReportList(decoded);
        if (list == null) {
          _error = 'Неожиданный формат списка отчётов: ${decoded.runtimeType}';
        } else {
          _reports = list
              .whereType<Map>()
              .map((j) => Report.fromJson(Map<String, dynamic>.from(j)))
              .toList();
        }
      } else {
        _error = _readError(response, 'Ошибка загрузки отчётов (HTTP ${response.statusCode})');
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
      final basePath = authProvider.isPatient
          ? '$_baseUrl/patient/report/$reportId'
          : '$_baseUrl/report/$reportId';
      final response = await http.get(
        Uri.parse('$basePath?page=$_currentReportPage&limit=$_currentReportLimit'),
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

  void resetReportAnalytics() {
    _analyticsPatients = [];
    _analyticsError = null;
    _analyticsLoading = false;
    _analyticsGenerating = false;
    _analyticsReportId = null;
    notifyListeners();
  }

  Future<void> loadReportAnalytics(BuildContext context, int reportId) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;

    _analyticsReportId = reportId;
    _analyticsLoading = true;
    _analyticsError = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/report/$reportId/patients'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final pat = json.decode(response.body);
        if (pat is List) {
          _analyticsPatients = pat.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _analyticsPatients = [];
        }
      } else {
        _analyticsPatients = [];
        _analyticsError = 'Аналитика: HTTP ${response.statusCode}';
      }
    } catch (e) {
      _analyticsError = 'Ошибка загрузки аналитики: $e';
      _analyticsPatients = [];
    } finally {
      _analyticsLoading = false;
      notifyListeners();
    }
  }

  Future<String?> generateReportAnalytics(BuildContext context, int reportId) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return 'Нет авторизации';

    _analyticsGenerating = true;
    _analyticsError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/report/$reportId/generate'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        await loadReportAnalytics(context, reportId);
        return null;
      }
      final err = _parseErrorBody(response.body);
      _analyticsError = err ?? 'Генерация аналитики: HTTP ${response.statusCode}';
      return _analyticsError;
    } catch (e) {
      _analyticsError = 'Ошибка: $e';
      return _analyticsError;
    } finally {
      _analyticsGenerating = false;
      notifyListeners();
    }
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
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final list = _extractReportList(decoded);
        if (list == null) {
          _adminError = 'Неожиданный формат /admin/reports: ${decoded.runtimeType}';
        } else {
          _adminReports = list
              .whereType<Map>()
              .map((j) => Report.fromJson(Map<String, dynamic>.from(j)))
              .toList();
        }
      } else {
        _adminError = _readError(response, 'Ошибка загрузки всех отчётов (HTTP ${response.statusCode})');
      }
    } catch (e) {
      _adminError = 'Ошибка сети: $e';
    } finally {
      _adminIsLoading = false;
      notifyListeners();
    }
  }

List<dynamic>? _extractReportList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['items', 'content', 'reports', 'data']) {
        final v = decoded[key];
        if (v is List) return v;
      }
    }
    return null;
  }

  String _readError(http.Response resp, String fallback) {
    try {
      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return fallback;
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
        Uri.parse('$_baseUrl/admin/report/$reportId?page=1&limit=500'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic>? patients;
        if (decoded is Map) {
          final p = decoded['patients'] ?? decoded['report'] ?? decoded['items'];
          if (p is List) patients = p;
        } else if (decoded is List) {
          patients = decoded;
        }
        if (patients == null) {
          _adminError = 'Неожиданный формат /admin/report: ${decoded.runtimeType}';
        } else {
          _adminCurrentReport = patients
              .whereType<Map>()
              .map((j) => PatientReport.fromJson(Map<String, dynamic>.from(j)))
              .toList();
          if (reportObject != null) {
            _adminReportToShow = reportObject;
          }
        }
      } else {
        _adminError = _readError(response, 'Ошибка загрузки деталей отчёта (HTTP ${response.statusCode})');
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
        await loadAdminReports(context);
      }
    } catch (e) {
    } finally {
      _adminIsLoading = false;
      notifyListeners();
    }
  }
} 