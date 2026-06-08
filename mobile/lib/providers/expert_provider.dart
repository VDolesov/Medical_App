import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_provider.dart';

class ExpertExecution {
  final String ruleCode;
  final String severity;
  final String? ruleTitle;
  final String? category;
  final String? explanation;
  final String? patientExplanation;
  final Map<String, dynamic>? matchedFacts;
  final Map<String, dynamic>? actionJson;
  final String? sourceCode;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceSection;
  final String? createdAt;

  ExpertExecution({
    required this.ruleCode,
    required this.severity,
    this.ruleTitle,
    this.category,
    this.explanation,
    this.patientExplanation,
    this.matchedFacts,
    this.actionJson,
    this.sourceCode,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceSection,
    this.createdAt,
  });

  factory ExpertExecution.fromJson(Map<String, dynamic> json) {
    return ExpertExecution(
      ruleCode: json['ruleCode']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'INFO',
      ruleTitle: json['ruleTitle']?.toString(),
      category: json['category']?.toString(),
      explanation: json['explanation']?.toString(),
      patientExplanation: json['patientExplanation']?.toString(),
      matchedFacts: json['matchedFacts'] is Map ? Map<String, dynamic>.from(json['matchedFacts'] as Map) : null,
      actionJson: json['actionJson'] is Map ? Map<String, dynamic>.from(json['actionJson'] as Map) : null,
      sourceCode: json['sourceCode']?.toString(),
      sourceTitle: json['sourceTitle']?.toString(),
      sourceUrl: json['sourceUrl']?.toString(),
      sourceSection: json['sourceSection']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class ExpertReportPatientResult {
  final int reportPatientId;
  final String overallSeverity;
  final int triggeredCount;
  final List<ExpertExecution> executions;

  ExpertReportPatientResult({
    required this.reportPatientId,
    required this.overallSeverity,
    required this.triggeredCount,
    required this.executions,
  });

  factory ExpertReportPatientResult.fromJson(Map<String, dynamic> json) {
    final list = json['executions'];
    final execs = <ExpertExecution>[];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          execs.add(ExpertExecution.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return ExpertReportPatientResult(
      reportPatientId: (json['reportPatientId'] as num?)?.toInt() ?? 0,
      overallSeverity: json['overallSeverity']?.toString() ?? 'INFO',
      triggeredCount: (json['triggeredCount'] as num?)?.toInt() ?? execs.length,
      executions: execs,
    );
  }
}

class ExpertProvider with ChangeNotifier {
  static const String _baseUrl = ApiConfig.baseUrl;

  final Map<int, ExpertReportPatientResult> _byReportPatient = {};
  final Set<int> _loading = {};
  String? _lastError;

  String? get lastError => _lastError;

  ExpertReportPatientResult? resultFor(int reportPatientId) => _byReportPatient[reportPatientId];
  bool isLoading(int reportPatientId) => _loading.contains(reportPatientId);

  Future<void> loadFor(AuthProvider auth, int reportPatientId) async {
    if (auth.token == null) return;
    _loading.add(reportPatientId);
    _lastError = null;
    notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/expert/report-patient/$reportPatientId/executions'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          _byReportPatient[reportPatientId] = ExpertReportPatientResult.fromJson(decoded);
        }
      } else {
        _lastError = 'Экспертная система: HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _lastError = 'Ошибка загрузки экспертных выводов: $e';
    } finally {
      _loading.remove(reportPatientId);
      notifyListeners();
    }
  }

  Future<String?> reEvaluate(AuthProvider auth, int reportPatientId) async {
    if (auth.token == null) return 'Нет авторизации';
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/expert/report-patient/$reportPatientId/re-evaluate'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );
      if (resp.statusCode == 200) {
        await loadFor(auth, reportPatientId);
        return null;
      }
      return 'Пересчёт правил: HTTP ${resp.statusCode}';
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  List<Map<String, dynamic>> _rules = [];
  bool _rulesLoading = false;
  String? _rulesError;

  List<Map<String, dynamic>> get rules => List.unmodifiable(_rules);
  bool get rulesLoading => _rulesLoading;
  String? get rulesError => _rulesError;

  Future<void> loadRules(AuthProvider auth) async {
    if (auth.token == null) return;
    _rulesLoading = true;
    _rulesError = null;
    notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/expert/rules'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          _rules = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else {
        _rulesError = 'Каталог правил: HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _rulesError = 'Ошибка: $e';
    } finally {
      _rulesLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _byReportPatient.clear();
    _loading.clear();
    _lastError = null;
    _rules = [];
    _rulesError = null;
    notifyListeners();
  }
}
