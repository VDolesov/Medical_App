import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../api/pdf_download.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/expert_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/severity_badge.dart';

class ReportDetailScreen extends StatefulWidget {
  final int reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final reports = context.read<ReportsProvider>();
      await reports.loadDetail(widget.reportId, isPatient: auth.isPatient, isAdmin: auth.isAdmin);
      if (!mounted) return;
      await reports.loadAnalytics(widget.reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reports = context.watch<ReportsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёт'),
        actions: [
          if (!auth.isPatient)
            IconButton(
              tooltip: 'Привязать строки к пациентам',
              icon: const Icon(Icons.link),
              onPressed: () => context.push('/reports/${widget.reportId}/bind'),
            ),
        ],
      ),
      body: _body(context, reports, auth),
    );
  }

  Widget _body(BuildContext context, ReportsProvider reports, AuthProvider auth) {
    if (reports.loadingDetail && reports.detail.isEmpty) {
      return const LoadingIndicator(message: 'Загружаем пациентов…');
    }
    if (reports.detailError != null && reports.detail.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить отчёт',
        subtitle: reports.detailError,
      );
    }
    if (reports.detail.isEmpty) {
      return const EmptyState(icon: Icons.description_outlined, title: 'Нет данных');
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _analyticsCard(context, auth)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList.separated(
            itemCount: reports.detail.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _PatientCard(reportId: widget.reportId, row: reports.detail[i]),
          ),
        ),
      ],
    );
  }

  Widget _analyticsCard(BuildContext context, AuthProvider auth) {
    if (auth.isPatient) return const SizedBox.shrink();
    final reports = context.watch<ReportsProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        color: scheme.primaryContainer.withOpacity(0.55),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text('Аналитика отчёта',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Запустите расчёт, чтобы экспертная система обработала всех пациентов по клиническим правилам.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (reports.analyticsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(reports.analyticsError!, style: TextStyle(color: scheme.error)),
                ),
              FilledButton.icon(
                onPressed: reports.analyticsRunning
                    ? null
                    : () async {
                        final err = await context.read<ReportsProvider>().runAnalytics(widget.reportId);
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                icon: reports.analyticsRunning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate_outlined),
                label: Text(reports.analyticsRunning ? 'Считаем…' : 'Рассчитать аналитику'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _avatarInitials(String code) {
  final s = code.trim();
  if (s.isEmpty) return '?';
  if (s.length <= 2) return s.toUpperCase();
  if (s.startsWith('P-') && s.length >= 4) return s.substring(2, 4);
  return s.substring(0, 2).toUpperCase();
}

class _PatientCard extends StatelessWidget {
  final int reportId;
  final ReportPatientRow row;
  const _PatientCard({required this.reportId, required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reports = context.watch<ReportsProvider>();
    final rpId = reports.reportPatientIdFor(row);
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
              _avatarInitials(row.code),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          title: Text(row.code.isEmpty ? '—' : row.code,
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text('Возраст: ${row.age}   ·   Отклонений: ${row.outOfNorms.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          children: [
            if (row.outOfNorms.isEmpty)
              Text('Все значения в норме',
                  style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w500))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: row.outOfNorms.whereType<Map>().map((d) {
                  final m = Map<String, dynamic>.from(d);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record, size: 10, color: scheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${m['analysis']}: ${m['value']} ${m['unit']} · ${m['status']} (норма ${m['min']}–${m['max']})',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (rpId != null) ...[
              const SizedBox(height: 12),
              _ExpertFindings(reportPatientId: rpId, patient: row),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Готовим PDF…'), duration: Duration(seconds: 2)),
                    );
                    final err = await PdfDownload.downloadPatientReport(
                      reportId: reportId,
                      reportPatientId: rpId,
                      token: auth.token,
                    );
                    if (err != null) {
                      messenger.showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Скачать PDF'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpertFindings extends StatefulWidget {
  final int reportPatientId;
  final ReportPatientRow patient;
  const _ExpertFindings({required this.reportPatientId, required this.patient});

  @override
  State<_ExpertFindings> createState() => _ExpertFindingsState();
}

class _ExpertFindingsState extends State<_ExpertFindings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final expert = context.read<ExpertProvider>();
      if (expert.resultFor(widget.reportPatientId) == null) {
        expert.load(widget.reportPatientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer2<ExpertProvider, AuthProvider>(
      builder: (context, expert, auth, _) {
        final r = expert.resultFor(widget.reportPatientId);
        final loading = expert.isLoading(widget.reportPatientId);
        final isPatient = auth.isPatient;
        return Container(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.psychology_alt_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Экспертная система',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (r != null) SeverityBadge(severity: r.overallSeverity, compact: true),
              ]),
              const SizedBox(height: 8),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (r == null)
                Text('Нет данных. Нажмите «Обновить» или попросите врача запустить расчёт.',
                    style: Theme.of(context).textTheme.bodySmall)
              else if (r.executions.isEmpty)
                Text('По загруженным данным правила замечаний не сформировали.',
                    style: Theme.of(context).textTheme.bodyMedium)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: r.executions
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _RuleRow(execution: e, isPatient: isPatient),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: loading ? null : () => context.read<ExpertProvider>().load(widget.reportPatientId),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Обновить'),
                  ),
                  if (!isPatient)
                    TextButton.icon(
                      onPressed: loading
                          ? null
                          : () async {
                              final err = await context.read<ExpertProvider>().reEvaluate(widget.reportPatientId);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              }
                            },
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: const Text('Пересчитать'),
                    ),
                  TextButton.icon(
                    onPressed: () => _openChat(context, isPatient: isPatient),
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

  Future<void> _openChat(BuildContext context, {required bool isPatient}) async {
    final chat = context.read<ChatProvider>();
    int? tid;
    if (isPatient) {
      tid = await chat.openWithMyDoctor();
    } else if (widget.patient.linkPatientId != null) {
      tid = await chat.openByPatientId(widget.patient.linkPatientId!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пациент не привязан, чат невозможен')),
      );
      return;
    }
    if (!context.mounted) return;
    if (tid != null) {
      context.push('/chats/$tid');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.threadsError ?? 'Не удалось открыть чат')),
      );
    }
  }
}

class _RuleRow extends StatelessWidget {
  final ExpertExecution execution;
  final bool isPatient;
  const _RuleRow({required this.execution, required this.isPatient});

  @override
  Widget build(BuildContext context) {
    final color = AppThemeColor.severityColor(context, execution.severity);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isPatient)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(execution.ruleCode,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              Expanded(
                child: Text(execution.ruleTitle ?? execution.ruleCode,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if ((execution.explanation ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(execution.explanation!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (!isPatient && execution.sourceCode != null) ...[
            const SizedBox(height: 6),
            Text(
              'Источник: ${execution.sourceCode}${execution.sourceSection != null ? ' · ${execution.sourceSection}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppThemeColor {
  static Color severityColor(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity.toUpperCase()) {
      'CRITICAL' => scheme.error,
      'WARNING' => Theme.of(context).colorScheme.tertiary,
      'INFO' => scheme.primary,
      _ => scheme.outline,
    };
  }
}
