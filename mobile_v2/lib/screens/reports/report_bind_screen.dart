import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/patient_picker.dart';

class ReportBindScreen extends StatefulWidget {
  final int reportId;

  const ReportBindScreen({super.key, required this.reportId});

  @override
  State<ReportBindScreen> createState() => _ReportBindScreenState();
}

class _ReportBindScreenState extends State<ReportBindScreen> {
  Map<String, String> _headers() {
    final t = context.read<AuthProvider>().token;
    return {
      if (t != null) 'Authorization': 'Bearer $t',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  String _routePrefix() {
    final auth = context.read<AuthProvider>();
    return auth.isAdmin ? '/admin' : '/doctor';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ReportsProvider>().loadDetail(widget.reportId,
          isPatient: false, isAdmin: auth.isAdmin);
    });
  }

  Future<void> _bind(int rowIndex, String code) async {
    final r = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${_routePrefix()}/reports/${widget.reportId}/rows/$rowIndex/patient'),
      headers: _headers(),
      body: json.encode({'patient_code': code}),
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Привязано')));
      await _reload();
    } else {
      _toastError(r);
    }
  }

  Future<void> _unbind(int rowIndex) async {
    final r = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${_routePrefix()}/reports/${widget.reportId}/rows/$rowIndex/patient'),
      headers: _headers(),
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отвязано')));
      await _reload();
    } else {
      _toastError(r);
    }
  }

  void _toastError(http.Response r) {
    String msg = 'HTTP ${r.statusCode}';
    try {
      final m = json.decode(utf8.decode(r.bodyBytes));
      if (m is Map && m['error'] != null) msg = m['error'].toString();
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    await context.read<ReportsProvider>().loadDetail(widget.reportId,
        isPatient: false, isAdmin: auth.isAdmin);
  }

  Future<void> _editCode(int rowIndex, String? currentCode) async {
    final code = await showPatientPicker(context);
    if (!mounted) return;
    if (code == null || code.isEmpty) return;
    await _bind(rowIndex, code);
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Привязка строк'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: _body(reports),
    );
  }

  Widget _body(ReportsProvider reports) {
    if (reports.loadingDetail && reports.detail.isEmpty) {
      return const LoadingIndicator();
    }
    if (reports.detailError != null && reports.detail.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: reports.detailError,
        actionLabel: 'Повторить',
        onAction: _reload,
      );
    }
    if (reports.detail.isEmpty) {
      return const EmptyState(icon: Icons.description_outlined, title: 'В отчёте нет строк');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: reports.detail.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final row = reports.detail[i];
        return _RowCard(
          rowIndex: row.rowIndex ?? i,
          row: row,
          onBindNew: () => _editCode(row.rowIndex ?? i, null),
          onChangeCode: () => _editCode(row.rowIndex ?? i, row.code),
          onUnbind: row.linkPatientId == null ? null : () => _unbind(row.rowIndex ?? i),
        );
      },
    );
  }
}

class _RowCard extends StatelessWidget {
  final int rowIndex;
  final ReportPatientRow row;
  final VoidCallback onBindNew;
  final VoidCallback onChangeCode;
  final VoidCallback? onUnbind;

  const _RowCard({
    required this.rowIndex,
    required this.row,
    required this.onBindNew,
    required this.onChangeCode,
    this.onUnbind,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final linked = row.linkPatientId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text('#${rowIndex + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.code.isEmpty ? 'Без кода' : row.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: linked ? scheme.tertiaryContainer : scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    linked ? 'Привязано' : 'Не привязано',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: linked ? scheme.onTertiaryContainer : scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Возраст: ${row.age}  ·  Отклонений: ${row.outOfNorms.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (linked)
                  OutlinedButton.icon(
                    onPressed: onChangeCode,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Сменить'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onBindNew,
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Привязать'),
                  ),
                if (onUnbind != null)
                  TextButton.icon(
                    onPressed: onUnbind,
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('Отвязать'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
