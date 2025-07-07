import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadReports(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/admin_reports');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчеты'),
        actions: [
          Consumer<ReportsProvider>(
            builder: (context, reportsProvider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => reportsProvider.loadReports(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, reportsProvider, child) {
          if (reportsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (reportsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки отчетов',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reportsProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => reportsProvider.loadReports(context),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (reportsProvider.reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет отчетов',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Загрузите файл с анализами, чтобы увидеть отчеты',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/upload'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Загрузить файл'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => reportsProvider.loadReports(context),
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reportsProvider.reports.length,
                  itemBuilder: (context, index) {
                    final report = reportsProvider.reports[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.description,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        title: Text(
                          report.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${report.id}'),
                            Text('Создан: ${_formatDate(report.createdAt)}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'view') {
                              reportsProvider.loadReportDetails(context, report.id, reportObject: report);
                            } else if (value == 'delete') {
                              _showDeleteConfirmation(context, report);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('Просмотреть'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Удалить', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          reportsProvider.loadReportDetails(context, report.id, reportObject: report);
                        },
                      ),
                    );
                  },
                ),
                // SnackBar и модалка через postFrameCallback
                Consumer<ReportsProvider>(
                  builder: (context, provider, _) {
                    if (provider.snackBarMessage != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.snackBarMessage!)),
                          );
                          provider.clearSnackBarMessage();
                        }
                      });
                    }
                    if (provider.shouldShowReportDetails && provider.currentReport.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _showReportDetails(context, provider.reportToShow, provider.currentReport);
                          provider.hideReportDetails();
                        }
                      });
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReportDetails(BuildContext context, dynamic report, List<PatientReport> currentReport) {
    if (!mounted) return;
    if (currentReport.isEmpty) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.assessment,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Детали отчета',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          report.fileName,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        // Debug info
                        Text(
                          'Debug: currentReport.length = \\${currentReport.length}',
                          style: const TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Содержимое отчета
            Expanded(
              child: Consumer<ReportsProvider>(
                builder: (context, reportsProvider, _) => NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 && reportsProvider.hasMore && !reportsProvider.isLoading) {
                      reportsProvider.loadMoreReportDetails(context, report.id);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: currentReport.length + (reportsProvider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= currentReport.length) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final patientReport = currentReport[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(
                            'Пациент \\${patientReport.code}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text('Возраст: \\${patientReport.age} лет'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (patientReport.outOfNorms is List) ...[
                                    if (patientReport.outOfNorms.isEmpty)
                                      const Text(
                                        'Все показатели в норме',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    else ...[
                                      const Text(
                                        'Отклонения от нормы:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...patientReport.outOfNorms.map((deviation) {
                                        if (deviation is Map) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              border: Border.all(color: Colors.red.shade200),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  deviation['analysis'] ?? 'Анализ',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Значение: \\${deviation['value']} \\${deviation['unit']}',
                                                ),
                                                Text(
                                                  'Норма: \\${deviation['min']} - \\${deviation['max']} \\${deviation['unit']}',
                                                ),
                                                Text(
                                                  'Статус: \\${deviation['status']}',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              border: Border.all(color: Colors.green.shade200),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              deviation.toString(),
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }
                                      }).toList(),
                                    ],
                                  ] else ...[
                                    Text(
                                      'Данные отклонений: \\${patientReport.outOfNorms.toString()}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление отчета'),
        content: Text(
          'Вы уверены, что хотите удалить отчет "${report.fileName}"? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final reportsProvider = context.read<ReportsProvider>();
              final success = await reportsProvider.deleteReport(context, report.id);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Отчет успешно удален'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} в ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
} 