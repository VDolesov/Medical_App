import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Админка')),
        body: const Center(child: Text('Доступно только администратору')),
      );
    }
    final tiles = const [
      _AdminTile('База знаний', 'Клинические правила экспертной системы',
          Icons.psychology_alt_outlined, '/admin/knowledge'),
      _AdminTile('Пользователи', 'Врачи и админы: создание, редактирование, удаление',
          Icons.manage_accounts_outlined, '/admin/users'),
      _AdminTile('Пациенты', 'Закрепление за врачами, лк, поиск',
          Icons.groups_outlined, '/admin/patients'),
      _AdminTile('Все отчёты', 'Отчёты всех врачей в системе',
          Icons.assessment_outlined, '/admin/reports'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Админка')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = tiles[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: Icon(t.icon),
              ),
              title: Text(t.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(t.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(t.route),
            ),
          );
        },
      ),
    );
  }
}

class _AdminTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const _AdminTile(this.title, this.subtitle, this.icon, this.route);
}
