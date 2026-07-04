import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class ExpertExecution {
  final String ruleCode;
  final String severity;
  final String? ruleTitle;
  final String? explanation;
  final String? patientExplanation;
  final String? sourceCode;
  final String? sourceSection;
  final Map<String, dynamic>? matchedFacts;
  final Map<String, dynamic>? actionJson;

  ExpertExecution({
    required this.ruleCode,
    required this.severity,
    this.ruleTitle,
    this.explanation,
    this.patientExplanation,
    this.sourceCode,
    this.sourceSection,
    this.matchedFacts,
    this.actionJson,
  });

  factory ExpertExecution.fromJson(Map<String, dynamic> j) => ExpertExecution(
        ruleCode: j['ruleCode']?.toString() ?? '?',
        severity: j['severity']?.toString() ?? 'INFO',
        ruleTitle: j['ruleTitle']?.toString(),
        explanation: j['explanation']?.toString(),
        patientExplanation: j['patientExplanation']?.toString(),
        sourceCode: j['sourceCode']?.toString(),
        sourceSection: j['sourceSection']?.toString(),
        matchedFacts: j['matchedFacts'] is Map ? Map<String, dynamic>.from(j['matchedFacts'] as Map) : null,
        actionJson: j['actionJson'] is Map ? Map<String, dynamic>.from(j['actionJson'] as Map) : null,
      );
}

class ExpertResult {
  final int reportPatientId;
  final String overallSeverity;
  final List<ExpertExecution> executions;

  ExpertResult({required this.reportPatientId, required this.overallSeverity, required this.executions});

  factory ExpertResult.fromJson(Map<String, dynamic> j) {
    final list = j['executions'];
    final execs = <ExpertExecution>[];
    if (list is List) {
      for (final e in list) {
        if (e is Map) execs.add(ExpertExecution.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return ExpertResult(
      reportPatientId: (j['reportPatientId'] as num?)?.toInt() ?? 0,
      overallSeverity: j['overallSeverity']?.toString() ?? 'INFO',
      executions: execs,
    );
  }
}

class ExpertProvider with ChangeNotifier {
  final ApiClient _api;

  ExpertProvider(this._api);

  final Map<int, ExpertResult> _byRp = {};
  final Set<int> _loading = {};
  String? _lastError;

  ExpertResult? resultFor(int rpId) => _byRp[rpId];
  bool isLoading(int rpId) => _loading.contains(rpId);
  String? get lastError => _lastError;

  Future<void> load(int rpId) async {
    _loading.add(rpId);
    _lastError = null;
    notifyListeners();
    final r = await _api.get('/expert/report-patient/$rpId/executions');
    if (r.ok && r.body is Map) {
      _byRp[rpId] = ExpertResult.fromJson(Map<String, dynamic>.from(r.body));
    } else {
      _lastError = r.errorMessage;
    }
    _loading.remove(rpId);
    notifyListeners();
  }

  Future<String?> reEvaluate(int rpId) async {
    final r = await _api.post('/expert/report-patient/$rpId/re-evaluate');
    if (r.ok) {
      await load(rpId);
      return null;
    }
    return r.errorMessage ?? 'Не удалось пересчитать';
  }
}
