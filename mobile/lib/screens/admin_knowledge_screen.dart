import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/admin_knowledge_provider.dart';
import '../providers/auth_provider.dart';

class AdminKnowledgeScreen extends StatefulWidget {
  const AdminKnowledgeScreen({super.key});

  @override
  State<AdminKnowledgeScreen> createState() => _AdminKnowledgeScreenState();
}

class _AdminKnowledgeScreenState extends State<AdminKnowledgeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AdminKnowledgeProvider>().loadAll(auth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('База знаний'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminKnowledgeProvider>().loadAll(context.read<AuthProvider>()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/knowledge/new'),
        icon: const Icon(Icons.add),
        label: const Text('Создать правило'),
      ),
      body: Consumer2<AdminKnowledgeProvider, AuthProvider>(
        builder: (context, provider, auth, _) {
          if (!auth.isAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Доступно только администратору', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          if (provider.loading && provider.rules.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.rules.isEmpty) {
            return _errorView(context, auth, provider.error!);
          }
          if (provider.rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Каталог пуст. Нажмите «Создать правило».',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadAll(auth),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount: provider.rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _RuleCard(rule: provider.rules[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _errorView(BuildContext context, AuthProvider auth, String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(err, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<AdminKnowledgeProvider>().loadAll(auth),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;

  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    final id = (rule['id'] as num?)?.toInt();
    final code = rule['code']?.toString() ?? '?';
    final title = rule['title']?.toString() ?? '?';
    final severity = rule['severity']?.toString() ?? 'INFO';
    final category = rule['category']?.toString() ?? '';
    final active = rule['active'] == true || rule['isActive'] == true;
    final priority = (rule['priority'] as num?)?.toInt() ?? 100;
    final sourceCode = rule['sourceCode']?.toString();
    final sourceSection = rule['sourceSection']?.toString();

    final sevColor = switch (severity.toUpperCase()) {
      'CRITICAL' => Colors.red.shade700,
      'WARNING' => Colors.orange.shade700,
      _ => Colors.green.shade700,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sevColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sevColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: sevColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!active)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.pause_circle_filled, size: 18, color: Colors.grey),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _RuleMenu(rule: rule),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Chip(text: category, color: Colors.indigo.shade50, fg: Colors.indigo.shade700),
                _Chip(text: 'prio $priority', color: Colors.grey.shade200, fg: Colors.grey.shade800),
                if (sourceCode != null && sourceCode.isNotEmpty)
                  _Chip(
                    text: sourceSection != null && sourceSection.isNotEmpty
                        ? '$sourceCode · $sourceSection'
                        : sourceCode,
                    color: Colors.teal.shade50,
                    fg: Colors.teal.shade800,
                  ),
              ],
            ),
            if (id != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Switch(
                    value: active,
                    onChanged: (v) async {
                      final auth = context.read<AuthProvider>();
                      final err = await context
                          .read<AdminKnowledgeProvider>()
                          .toggleRule(auth, id, v);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  ),
                  Text(active ? 'Активно' : 'Выключено',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.push('/admin/knowledge/$id'),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Редактировать'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final Color fg;

  const _Chip({required this.text, required this.color, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _RuleMenu extends StatelessWidget {
  final Map<String, dynamic> rule;

  const _RuleMenu({required this.rule});

  @override
  Widget build(BuildContext context) {
    final id = (rule['id'] as num?)?.toInt();
    if (id == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      onSelected: (v) async {
        final auth = context.read<AuthProvider>();
        final provider = context.read<AdminKnowledgeProvider>();
        if (v == 'edit') {
          context.push('/admin/knowledge/$id');
        } else if (v == 'delete') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Удаление правила'),
              content: Text('Удалить «${rule['code']}»? Это действие нельзя отменить.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
          if (ok == true) {
            final err = await provider.deleteRule(auth, id);
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            }
          }
        }
      },
      itemBuilder: (c) => const [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Редактировать')])),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: Colors.red))])),
      ],
    );
  }
}
