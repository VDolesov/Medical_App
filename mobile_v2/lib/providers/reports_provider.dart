import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class ReportSummary {
  final int id;
  final String fileName;
  final DateTime createdAt;
  final String? doctorLabel;

  ReportSummary({required this.id, required this.fileName, required this.createdAt, this.doctorLabel});

  factory ReportSummary.fromJson(Map<String, dynamic> j) {
    DateTime created;
    final raw = j['created_at'] ?? j['createdAt'];
    if (raw is String) {
      created = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      created = DateTime.fromMillisecondsSinceEpoch(raw > 1e12 ? raw : raw * 1000);
    } else {
      created = DateTime.now();
    }
    final fn = (j['lastName'] ?? j['last_name'] ?? '').toString();
    final ln = (j['firstName'] ?? j['first_name'] ?? '').toString();
    final un = (j['username'] ?? '').toString();
    final lbl = ('$fn $ln').trim();
    final doctor = lbl.isEmpty ? (un.isEmpty ? null : un) : (un.isEmpty ? lbl : '$lbl ($un)');
    return ReportSummary(
      id: (j['id'] as num).toInt(),
      fileName: (j['file_name'] ?? j['fileName'] ?? '').toString(),
      createdAt: created,
      doctorLabel: doctor,
    );
  }
}

class ReportPatientRow {
  final String code;
  final int age;
  final int? rowIndex;
  final List<dynamic> outOfNorms;
  final int? linkPatientId;

  ReportPatientRow({
    required this.code,
    required this.age,
    required this.rowIndex,
    required this.outOfNorms,
    required this.linkPatientId,
  });

  factory ReportPatientRow.fromJson(Map<String, dynamic> j) => ReportPatientRow(
        code: j['code']?.toString() ?? '',
        age: (j['age'] as num?)?.toInt() ?? 0,
        rowIndex: (j['row_index'] as num?)?.toInt(),
        outOfNorms: j['outOfNorms'] is List ? List<dynamic>.from(j['outOfNorms']) : const [],
        linkPatientId: (j['link_patient_id'] as num?)?.toInt(),
      );
}

class ReportsProvider with ChangeNotifier {
  final ApiClient _api;

  ReportsProvider(this._api);

  List<ReportSummary> _list = [];
  bool _loadingList = false;
  String? _listError;
  bool get loadingList => _loadingList;
  String? get listError => _listError;
  List<ReportSummary> get list => List.unmodifiable(_list);

  List<ReportPatientRow> _detail = [];
  bool _loadingDetail = false;
  String? _detailError;
  bool get loadingDetail => _loadingDetail;
  String? get detailError => _detailError;
  List<ReportPatientRow> get detail => List.unmodifiable(_detail);

  List<Map<String, dynamic>> _analyticsPatients = [];
  List<Map<String, dynamic>> get analyticsPatients => List.unmodifiable(_analyticsPatients);
  bool _analyticsRunning = false;
  String? _analyticsError;
  bool get analyticsRunning => _analyticsRunning;
  String? get analyticsError => _analyticsError;

  Future<void> loadList({required bool isPatient, required bool isAdmin}) async {
    _loadingList = true;
    _listError = null;
    notifyListeners();
    final path = isAdmin
        ? '/admin/reports'
        : isPatient
            ? '/patient/reports'
            : '/reports';
    final r = await _api.get(path);
    if (r.ok) {
      _list = r.asList().whereType<Map>().map((e) => ReportSummary.fromJson(Map<String, dynamic>.from(e))).toList();
    } else {
      _listError = r.errorMessage;
    }
    _loadingList = false;
    notifyListeners();
  }

  Future<void> loadDetail(int reportId, {required bool isPatient, required bool isAdmin}) async {
    _loadingDetail = true;
    _detailError = null;
    _detail = [];
    notifyListeners();
    final path = isAdmin
        ? '/admin/report/$reportId?page=1&limit=500'
        : isPatient
            ? '/patient/report/$reportId?page=1&limit=500'
            : '/report/$reportId?page=1&limit=500';
    final r = await _api.get(path);
    if (r.ok) {
      final raw = r.asList(wrapperKey: 'patients');
      _detail = raw
          .whereType<Map>()
          .map((e) => ReportPatientRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      _detailError = r.errorMessage;
    }
    _loadingDetail = false;
    notifyListeners();
  }

  Future<void> loadAnalytics(int reportId) async {
    final r = await _api.get('/analytics/report/$reportId/patients');
    if (r.ok) {
      _analyticsPatients = r.asList().whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      notifyListeners();
    }
  }

  Future<String?> runAnalytics(int reportId) async {
    _analyticsRunning = true;
    _analyticsError = null;
    notifyListeners();
    final r = await _api.post('/analytics/report/$reportId/generate');
    _analyticsRunning = false;
    if (r.ok) {
      await loadAnalytics(reportId);
      notifyListeners();
      return null;
    }
    _analyticsError = r.errorMessage;
    notifyListeners();
    return _analyticsError;
  }

  int? reportPatientIdFor(ReportPatientRow row) {
    for (final m in _analyticsPatients) {
      final so = (m['sortOrder'] ?? m['sort_order']) as num?;
      if (row.rowIndex != null && so != null && so.toInt() == row.rowIndex) {
        return (m['reportPatientId'] ?? m['report_patient_id']) as int?;
      }
    }
    for (final m in _analyticsPatients) {
      if ((m['patientCode'] ?? m['patient_code'])?.toString() == row.code) {
        return (m['reportPatientId'] ?? m['report_patient_id']) as int?;
      }
    }
    return null;
  }
}
