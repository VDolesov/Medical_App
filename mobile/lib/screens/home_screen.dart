import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/norms_provider.dart';

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
      context.read<ReportsProvider>().loadReports(context);
      context.read<NormsProvider>().loadNorms(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await authProvider.logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Выйти'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer3<AuthProvider, ReportsProvider, NormsProvider>(
        builder: (context, authProvider, reportsProvider, normsProvider, child) {
          final user = authProvider.user;

          return RefreshIndicator(
            onRefresh: () async {
              await reportsProvider.loadReports(context);
              await normsProvider.loadNorms(context);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Добро пожаловать!',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: user?.role == 'admin'
                                            ? Colors.red.shade100
                                            : user?.role == 'patient'
                                                ? Colors.teal.shade100
                                                : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user?.role == 'admin'
                                            ? 'Администратор'
                                            : user?.role == 'patient'
                                                ? 'Пациент'
                                                : 'Врач',
                                        style: TextStyle(
                                          color: user?.role == 'admin'
                                              ? Colors.red.shade700
                                              : user?.role == 'patient'
                                                  ? Colors.teal.shade700
                                                  : Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Статистика',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Отчетов',
                          (user?.role == 'admin'
                              ? reportsProvider.adminReports.length.toString()
                              : reportsProvider.reports.length.toString()),
                          Icons.assessment,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Норм',
                          normsProvider.norms.length.toString(),
                          Icons.medical_services,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Быстрые действия',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      if (user?.role != 'patient')
                        _buildActionCard(
                          'Загрузить файл',
                          Icons.upload_file,
                          Colors.blue,
                          () => context.go('/upload'),
                        ),
                      if (user?.role == 'admin')
                        _buildActionCard(
                          'Все отчёты (админ)',
                          Icons.admin_panel_settings,
                          Colors.red,
                          () => context.go('/admin_reports'),
                        )
                      else
                        _buildActionCard(
                          'Просмотр отчетов',
                          Icons.assessment,
                          Colors.green,
                          () => context.go('/reports'),
                        ),
                      if (user?.role == 'doctor')
                        _buildActionCard(
                          'Справочник пациентов',
                          Icons.people_outline,
                          Colors.indigo,
                          () => context.push('/doctor/patients'),
                        ),
                      _buildActionCard(
                        'Просмотр норм',
                        Icons.medical_services,
                        Colors.purple,
                        () => context.go('/norms'),
                      ),
                      if (user?.role == 'admin')
                        _buildActionCard(
                          'Управление нормами',
                          Icons.admin_panel_settings,
                          Colors.red,
                          () => context.go('/admin'),
                        ),
                      _buildActionCard(
                        'Профиль',
                        Icons.person,
                        Colors.deepPurple,
                        () => context.go('/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (reportsProvider.reports.isNotEmpty) ...[
                    Text(
                      'Последние отчеты',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...reportsProvider.reports.take(3).map((report) =>
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.description),
                          title: Text(report.fileName),
                          subtitle: Text(
                            'Создан: ${_formatDate(report.createdAt)}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            reportsProvider.loadReportDetails(context, report.id);
                            context.go('/reports');
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'О приложении',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Медицинское приложение для анализа данных пациентов с заболеваниями щитовидной железы. '
                            'Загружайте Excel файлы с анализами и получайте автоматические отчеты об отклонениях от нормы.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
} 