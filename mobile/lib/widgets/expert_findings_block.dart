import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/expert_provider.dart';
import '../providers/reports_provider.dart';

int? reportPatientIdFromAnalytics(ReportsProvider provider, PatientReport pr) {
  int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  for (final m in provider.analyticsPatients) {
    final so = toInt(m['sortOrder'] ?? m['sort_order']);
    if (pr.rowIndex != null && so != null && so == pr.rowIndex) {
      return toInt(m['reportPatientId'] ?? m['report_patient_id']);
    }
  }
  for (final m in provider.analyticsPatients) {
    final code = m['patientCode']?.toString() ?? m['patient_code']?.toString();
    if (code != null && code == pr.code) {
      return toInt(m['reportPatientId'] ?? m['report_patient_id']);
    }
  }
  return null;
}

class ExpertFindingsBlock extends StatefulWidget {
  final int reportPatientId;
  final VoidCallback? onChatWithPatient;
  final bool autoLoad;

  const ExpertFindingsBlock({
    super.key,
    required this.reportPatientId,
    this.onChatWithPatient,
    this.autoLoad = true,
  });

  @override
  State<ExpertFindingsBlock> createState() => _ExpertFindingsBlockState();
}

class _ExpertFindingsBlockState extends State<ExpertFindingsBlock> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        final expert = context.read<ExpertProvider>();
        if (expert.resultFor(widget.reportPatientId) == null) {
          expert.loadFor(auth, widget.reportPatientId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpertProvider, AuthProvider>(
      builder: (context, expert, auth, _) {
        final loading = expert.isLoading(widget.reportPatientId);
        final result = expert.resultFor(widget.reportPatientId);
        final isPatient = auth.isPatient;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_alt, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Экспертная система',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ),
                  if (result != null) _SeverityBadge(severity: result.overallSeverity),
                ],
              ),
              const SizedBox(height: 6),
              _AdvisoryNotice(isPatient: isPatient, hasChat: widget.onChatWithPatient != null),
              const SizedBox(height: 10),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (expert.lastError != null && result == null)
                Text(expert.lastError!, style: TextStyle(color: Colors.red.shade800))
              else if (result == null)
                Text(
                  'Нет сохранённых выводов. Нажмите «Обновить выводы» или попросите врача выполнить расчёт.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                )
              else if (result.executions.isEmpty)
                Text(
                  'По загруженным данным экспертные правила не сформировали дополнительных замечаний.',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.executions
                      .map((e) => _RuleCard(execution: e, asPatient: isPatient))
                      .toList(),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: loading
                        ? null
                        : () => context.read<ExpertProvider>().loadFor(auth, widget.reportPatientId),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Обновить выводы'),
                  ),
                  if (!isPatient)
                    TextButton.icon(
                      onPressed: loading
                          ? null
                          : () async {
                              final err = await context
                                  .read<ExpertProvider>()
                                  .reEvaluate(auth, widget.reportPatientId);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(err)));
                              }
                            },
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: const Text('Пересчитать правила'),
                    ),
                  if (widget.onChatWithPatient != null)
                    TextButton.icon(
                      onPressed: widget.onChatWithPatient,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(isPatient ? 'Написать врачу' : 'Написать пациенту'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdvisoryNotice extends StatelessWidget {
  final bool isPatient;
  final bool hasChat;

  const _AdvisoryNotice({required this.isPatient, required this.hasChat});

  @override
  Widget build(BuildContext context) {
    final text = isPatient
        ? 'Это справочная сводка по вашим анализам. Она не является диагнозом и не заменяет консультацию врача. '
            '${hasChat ? 'Если есть вопросы, напишите лечащему врачу в чате.' : 'Если есть вопросы, обсудите их с лечащим врачом.'}'
        : 'Выводы носят рекомендательный характер и предназначены для поддержки врачебного анализа. '
            'Окончательные решения о диагнозе, обследовании и терапии принимает врач с учётом полной клинической картины.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.grey.shade800),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (severity.toUpperCase()) {
      'CRITICAL' => ('Требует внимания', Colors.red.shade700),
      'WARNING' => ('Проверить', Colors.orange.shade700),
      'INFO' => ('Справочно', Colors.green.shade700),
      _ => (severity, Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final ExpertExecution execution;
  final bool asPatient;
  const _RuleCard({required this.execution, required this.asPatient});

  @override
  Widget build(BuildContext context) {
    final sevColor = switch (execution.severity.toUpperCase()) {
      'CRITICAL' => Colors.red.shade700,
      'WARNING' => Colors.orange.shade700,
      _ => Colors.green.shade700,
    };
    final title = execution.ruleTitle ?? execution.ruleCode;
    final text = asPatient
        ? (execution.patientExplanation ?? execution.explanation ?? '')
        : (execution.explanation ?? '');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: sevColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!asPatient)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    execution.ruleCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
          ],
          if (!asPatient) _DoctorDetails(execution: execution),
        ],
      ),
    );
  }
}

class _DoctorDetails extends StatelessWidget {
  final ExpertExecution execution;
  const _DoctorDetails({required this.execution});

  @override
  Widget build(BuildContext context) {
    final recs = _readRecommendations(execution.actionJson);
    final matched = execution.matchedFacts ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Общие ориентиры для врача:',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
          ),
          ...recs.map((r) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 12.5, height: 1.3))),
                  ],
                ),
              )),
        ],
        if (matched.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: matched.entries
                .map((e) => Chip(
                      label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.indigo.shade50,
                    ))
                .toList(),
          ),
        ],
        if (execution.sourceCode != null) ...[
          const SizedBox(height: 6),
          Text(
            'Источник: ${execution.sourceCode}${execution.sourceSection != null ? ' · ${execution.sourceSection}' : ''}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  static List<String> _readRecommendations(Map<String, dynamic>? action) {
    if (action == null) return const [];
    final raw = action['recommendations'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }
}
