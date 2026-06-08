import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/reports_provider.dart';
import '../widgets/report_analytics_block.dart';
import '../widgets/expert_findings_block.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadAdminReports(context);
    });
  }

  @override
  Widget build(BuildContext context) {

final rootContext = context;
    return Scaffold(
      appBar: AppBar(title: const Text('Все отчёты (админ)')),
      body: Consumer<ReportsProvider>(
        builder: (_, provider, __) {
          if (provider.adminIsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.adminError != null) {
            return Center(child: Text(provider.adminError!));
          }
          if (provider.adminReports.isEmpty) {
            return const Center(child: Text('Нет отчётов'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.adminReports.length,
            itemBuilder: (_, index) {
              final report = provider.adminReports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(report.fileName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${report.id}'),
                      Text('Врач: ${(report.lastName ?? '')} ${(report.firstName ?? '')} (${report.username ?? report.email ?? report.userId})'),
                      Text('Создан: ${report.createdAt}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.link),
                    tooltip: 'Привязка строк к пациентам',
                    onPressed: () => rootContext.push('/reports/${report.id}/row-bind', extra: true),
                  ),
                  onTap: () => _openReportDetails(rootContext, provider, report),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openReportDetails(BuildContext rootContext, ReportsProvider provider, dynamic report) async {
    debugPrint('[admin] onTap report ${report.id}');
    await provider.loadAdminReportDetails(rootContext, report.id, reportObject: report);
    debugPrint('[admin] loadAdminReportDetails done, '
        'patients=${provider.adminCurrentReport.length}, error=${provider.adminError}');
    if (!rootContext.mounted) {
      debugPrint('[admin] rootContext unmounted after details');
      return;
    }
    await provider.loadReportAnalytics(rootContext, report.id);
    if (!rootContext.mounted) {
      debugPrint('[admin] rootContext unmounted after analytics');
      return;
    }
    if (provider.adminError != null) {
      ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text(provider.adminError!)));
      return;
    }
    debugPrint('[admin] opening details page');
    await Navigator.of(rootContext).push(
      MaterialPageRoute(
        builder: (_) => _AdminReportDetailsPage(report: report),
        fullscreenDialog: true,
      ),
    );
    if (rootContext.mounted) {
      rootContext.read<ReportsProvider>().resetReportAnalytics();
    }
  }
}

class _AdminReportDetailsPage extends StatelessWidget {
  final dynamic report;
  const _AdminReportDetailsPage({required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(report.fileName ?? 'Отчёт', overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, _) {
          final patients = provider.adminCurrentReport;
          if (provider.adminIsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.adminError != null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(provider.adminError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade800)),
              ),
            );
          }
          if (patients.isEmpty) {
            return const Center(child: Text('Нет данных по отчёту'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ReportAnalyticsBlock(reportId: report.id),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Детали отчёта', style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Удалить отчёт',
                      onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить отчёт?'),
                          content: const Text('Вы уверены, что хотите удалить этот отчёт?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await provider.deleteAdminReport(context, report.id);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text('Пациент ${patient.code}'),
                      subtitle: Text('Возраст: ${patient.age}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (patient.outOfNorms is List && patient.outOfNorms.isNotEmpty)
                                ...patient.outOfNorms.map((deviation) {
                                  if (deviation is Map) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Анализ: ${deviation['analysis'] ?? ''}'),
                                        Text('Значение: ${deviation['value']} ${deviation['unit']}'),
                                        Text('Норма: ${deviation['min']} - ${deviation['max']} ${deviation['unit']}'),
                                        Text('Статус: ${deviation['status']}', style: const TextStyle(color: Colors.red)),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  } else {
                                    return Text(deviation.toString());
                                  }
                                }).toList()
                              else
                                const Text('Все показатели в норме', style: TextStyle(color: Colors.green)),
                              Consumer<ReportsProvider>(
                                builder: (context, rp, _) {
                                  final rpId = reportPatientIdFromAnalytics(rp, patient);
                                  if (rpId == null) return const SizedBox.shrink();
                                  return ExpertFindingsBlock(reportPatientId: rpId);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
        },
      ),
    );
  }
} 