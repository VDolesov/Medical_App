import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Все отчёты (админ)')),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, _) {
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
            itemBuilder: (context, index) {
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
                  onTap: () {
                    provider.loadAdminReportDetails(context, report.id, reportObject: report);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => _AdminReportDetailsModal(report: report),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminReportDetailsModal extends StatelessWidget {
  final dynamic report;
  const _AdminReportDetailsModal({required this.report});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, _) {
        final patients = provider.adminCurrentReport;
        if (provider.adminIsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (patients.isEmpty) {
          return const Center(child: Text('Нет данных по отчёту'));
        }
        return Column(
          children: [
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
                        Navigator.pop(context); // Закрыть модалку
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
    );
  }
} 