import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/reports_provider.dart';
import '../../theme/app_theme.dart';

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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin);
            await context.read<ChatProvider>().loadThreads();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _heroHeader(context, auth, chat),
              const SizedBox(height: 16),
              _statsRow(context, reports, chat),
              const SizedBox(height: 24),
              Text('Быстрые действия', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _quickActions(context, auth),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Последние отчёты', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (reports.list.length > 4)
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text('Все'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (reports.loadingList && reports.list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (reports.list.isEmpty)
                Card(
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReportTile(reportId: r.id, title: r.fileName, subtitle: r.doctorLabel ?? ''),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  /// Градиентная «шапка»: приветствие, имя, аватар, переход к чатам.
  Widget _heroHeader(BuildContext context, AuthProvider auth, ChatProvider chat) {
    final greeting = _greeting();
    final name = auth.user?.displayName ?? '';
    final initial = (auth.user?.firstName.isNotEmpty == true ? auth.user!.firstName[0] : '?').toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Text(
              initial,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: chat.unreadTotal > 0,
              label: Text(chat.unreadTotal > 99 ? '99+' : '${chat.unreadTotal}'),
              child: const Icon(Icons.forum_outlined, color: Colors.white),
            ),
            onPressed: () => context.go('/chats'),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(BuildContext context, ReportsProvider reports, ChatProvider chat) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.description_outlined,
            iconColor: AppTheme.brandEmerald,
            value: reports.list.length.toString(),
            label: 'Отчётов',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.mark_chat_unread_outlined,
            iconColor: AppTheme.brandOcean,
            value: chat.unreadTotal.toString(),
            label: 'Непрочитано',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.forum_outlined,
            iconColor: const Color(0xFFD97706),
            value: chat.threads.length.toString(),
            label: 'Диалогов',
          ),
        ),
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
      childAspectRatio: 2.3,
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
  final Color iconColor;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? scheme.surfaceContainerLow : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => context.push('/reports/$reportId'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.description_outlined, color: Colors.white, size: 22),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
