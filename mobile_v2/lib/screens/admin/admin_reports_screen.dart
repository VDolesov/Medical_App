import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/reports_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String? _doctorFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadList(isPatient: false, isAdmin: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final all = reports.list;
    final doctors = <String>{};
    for (final r in all) {
      if (r.doctorLabel != null) doctors.add(r.doctorLabel!);
    }
    final filtered = _doctorFilter == null
        ? all
        : all.where((r) => r.doctorLabel == _doctorFilter).toList();
    final fmt = DateFormat('dd MMM yyyy · HH:mm', 'ru');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Все отчёты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ReportsProvider>().loadList(isPatient: false, isAdmin: true),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('Все · ${all.length}'),
                    selected: _doctorFilter == null,
                    onSelected: (_) => setState(() => _doctorFilter = null),
                  ),
                ),
                ...doctors.map((d) {
                  final count = all.where((r) => r.doctorLabel == d).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('$d · $count'),
                      selected: _doctorFilter == d,
                      onSelected: (_) => setState(() => _doctorFilter = (_doctorFilter == d) ? null : d),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(context, reports, filtered, fmt)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ReportsProvider reports, List<ReportSummary> filtered, DateFormat fmt) {
    if (reports.loadingList && reports.list.isEmpty) {
      return const LoadingIndicator();
    }
    if (reports.listError != null && reports.list.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: reports.listError,
        actionLabel: 'Повторить',
        onAction: () =>
            context.read<ReportsProvider>().loadList(isPatient: false, isAdmin: true),
      );
    }
    if (filtered.isEmpty) {
      return const EmptyState(icon: Icons.assessment_outlined, title: 'Нет отчётов по фильтру');
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ReportsProvider>().loadList(isPatient: false, isAdmin: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = filtered[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/reports/${r.id}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.assessment_outlined, color: Theme.of(context).colorScheme.onTertiaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.fileName, style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            (r.doctorLabel ?? '—') + ' · ' + fmt.format(r.createdAt),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Привязать строки',
                      onPressed: () => context.push('/reports/${r.id}/bind'),
                      icon: const Icon(Icons.link_outlined),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
