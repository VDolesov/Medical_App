import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reports = context.watch<ReportsProvider>();
    final dateFmt = DateFormat('dd MMM yyyy · HH:mm', 'ru');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin),
          ),
        ],
      ),
      floatingActionButton: auth.isPatient
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/upload'),
              icon: const Icon(Icons.upload_file),
              label: const Text('Загрузить'),
            ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin),
        child: _body(context, reports, dateFmt),
      ),
    );
  }

  Widget _body(BuildContext context, ReportsProvider reports, DateFormat dateFmt) {
    if (reports.loadingList && reports.list.isEmpty) {
      return const LoadingIndicator(message: 'Загружаем отчёты…');
    }
    if (reports.listError != null && reports.list.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: reports.listError,
        actionLabel: 'Повторить',
        onAction: () {
          final auth = context.read<AuthProvider>();
          context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin);
        },
      );
    }
    if (reports.list.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Отчётов пока нет',
        subtitle: 'Загрузите Excel или попросите врача добавить ваши анализы.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: reports.list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = reports.list[i];
        return Card(
          child: InkWell(
            onTap: () => context.push('/reports/${r.id}'),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.fileName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          r.doctorLabel == null
                              ? dateFmt.format(r.createdAt)
                              : '${r.doctorLabel} · ${dateFmt.format(r.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
