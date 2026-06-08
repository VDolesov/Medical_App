import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/reports_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin);
      context.read<ChatProvider>().loadThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final reports = context.watch<ReportsProvider>();
    final chat = context.watch<ChatProvider>();
    final greeting = _greeting();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin);
            await context.read<ChatProvider>().loadThreads();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _header(context, greeting, auth),
              const SizedBox(height: 20),
              _statsRow(context, reports, chat),
              const SizedBox(height: 24),
              _quickActions(context, auth),
              const SizedBox(height: 24),
              Text('Последние отчёты',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (reports.loadingList && reports.list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (reports.list.isEmpty)
                Card(
                  color: scheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            auth.isPatient
                                ? 'Отчётов пока нет. Они появятся, когда врач загрузит ваши анализы.'
                                : 'Отчётов пока нет. Загрузите Excel из меню «Загрузка».',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...reports.list.take(4).map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReportTile(reportId: r.id, title: r.fileName, subtitle: r.doctorLabel ?? ''),
                    )),
              if (reports.list.length > 4)
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/reports'),
                    child: const Text('Все отчёты →'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String greeting, AuthProvider auth) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            (auth.user?.firstName.isNotEmpty == true ? auth.user!.firstName[0] : '?').toUpperCase(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              Text(auth.user?.displayName ?? '',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.go('/chats'),
        ),
      ],
    );
  }

  Widget _statsRow(BuildContext context, ReportsProvider reports, ChatProvider chat) {
    return Row(
      children: [
        Expanded(child: _StatCard(icon: Icons.description, value: reports.list.length.toString(), label: 'Отчётов')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.mark_chat_unread_outlined, value: chat.unreadTotal.toString(), label: 'Непрочитано')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.psychology_alt_outlined, value: '12', label: 'Правил')),
      ],
    );
  }

  Widget _quickActions(BuildContext context, AuthProvider auth) {
    final actions = <_Action>[
      if (!auth.isPatient) _Action('Загрузка Excel', Icons.upload_file_outlined, '/upload'),
      _Action('Мои отчёты', Icons.description_outlined, '/reports'),
      _Action('Чаты', Icons.chat_bubble_outline, '/chats'),
      if (auth.isAdmin) _Action('База знаний', Icons.psychology_alt_outlined, '/admin'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: actions
          .map((a) => _ActionTile(label: a.label, icon: a.icon, onTap: () => context.go(a.route)))
          .toList(),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Доброй ночи,';
    if (h < 12) return 'Доброе утро,';
    if (h < 18) return 'Добрый день,';
    return 'Добрый вечер,';
  }
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  _Action(this.label, this.icon, this.route);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 10),
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: scheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final int reportId;
  final String title;
  final String subtitle;
  const _ReportTile({required this.reportId, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/reports/$reportId'),
        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
