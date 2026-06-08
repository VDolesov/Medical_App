import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class ReportAnalyticsBlock extends StatelessWidget {
  final int reportId;

  const ReportAnalyticsBlock({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReportsProvider, AuthProvider>(
      builder: (context, reports, auth, _) {
        final canRun = auth.isDoctor || auth.isAdmin;
        if (!canRun) {
          return const SizedBox.shrink();
        }
        final err = reports.analyticsError;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Аналитика отчёта',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Запустите расчёт, чтобы экспертная система обработала всех пациентов отчёта по клиническим правилам (ATA 2015, КР РФ).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: reports.analyticsGenerating
                    ? null
                    : () async {
                        final msg = await reports.generateReportAnalytics(context, reportId);
                        if (context.mounted && msg != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      },
                icon: reports.analyticsGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.calculate_outlined, size: 20),
                label: Text(reports.analyticsGenerating ? 'Считаем…' : 'Рассчитать аналитику'),
              ),
            ],
          ),
        );
      },
    );
  }
}
