import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/severity_badge.dart';
import 'admin_rule_editor_screen.dart';

class AdminKnowledgeScreen extends StatefulWidget {
  const AdminKnowledgeScreen({super.key});

  @override
  State<AdminKnowledgeScreen> createState() => _AdminKnowledgeScreenState();
}

class _AdminKnowledgeScreenState extends State<AdminKnowledgeScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _loading = false;
  String? _error;

  Map<String, String> _headers() {
    final t = context.read<AuthProvider>().token;
    return {
      if (t != null) 'Authorization': 'Bearer $t',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await http.get(Uri.parse('${ApiConfig.baseUrl}/expert/rules'), headers: _headers());
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          _rules = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else {
        _error = 'HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> rule, bool active) async {
    final id = (rule['id'] as num).toInt();
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/expert/rules/$id/toggle'),
      headers: _headers(),
      body: json.encode({'active': active}),
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      await _load();
    } else {
      _toastError(r);
    }
  }

  Future<void> _delete(Map<String, dynamic> rule) async {
    final id = (rule['id'] as num).toInt();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить правило?'),
        content: Text('${rule['code']}: ${rule['title']}\n\nЭто действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/admin/expert/rules/$id'),
        headers: _headers());
    if (!mounted) return;
    if (r.statusCode == 200) {
      await _load();
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

  Future<void> _openEditor({Map<String, dynamic>? rule}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminRuleEditorScreen(initialRule: rule),
        fullscreenDialog: true,
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('База знаний'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Новое правило'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _rules.isEmpty) return const LoadingIndicator();
    if (_error != null && _rules.isEmpty) {
      return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Не удалось загрузить',
          subtitle: _error,
          actionLabel: 'Повторить',
          onAction: _load);
    }
    if (_rules.isEmpty) {
      return EmptyState(
        icon: Icons.psychology_alt_outlined,
        title: 'Каталог пуст',
        subtitle: 'Создайте первое правило клинической рекомендации.',
        actionLabel: 'Новое правило',
        onAction: () => _openEditor(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _RuleTile(
          rule: _rules[i],
          onToggle: (v) => _toggle(_rules[i], v),
          onDelete: () => _delete(_rules[i]),
          onEdit: () => _openEditor(rule: _rules[i]),
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final Map<String, dynamic> rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RuleTile({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final severity = rule['severity']?.toString() ?? 'INFO';
    final isActive = rule['active'] == true || rule['isActive'] == true;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(rule['code']?.toString() ?? '?',
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(width: 8),
                  if (!isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.pause_circle_outline, size: 16, color: scheme.outline),
                    ),
                  const Spacer(),
                  SeverityBadge(severity: severity, compact: true),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Редактировать')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(rule['title']?.toString() ?? '?',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (rule['category'] != null)
                    Chip(
                      label: Text(rule['category'].toString(), style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (rule['sourceCode'] != null)
                    Chip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 14),
                      label: Text(
                        rule['sourceSection'] == null
                            ? rule['sourceCode'].toString()
                            : '${rule['sourceCode']} · ${rule['sourceSection']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Switch(value: isActive, onChanged: onToggle),
                    Text(isActive ? 'Активно' : 'Выключено',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
