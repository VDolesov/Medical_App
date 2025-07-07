import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/norms_provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/foundation.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NormsProvider>().loadNorms(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Администрирование'),
        actions: [
          Consumer<NormsProvider>(
            builder: (context, normsProvider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => normsProvider.loadNorms(context),
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, NormsProvider>(
        builder: (context, authProvider, normsProvider, child) {
          // Проверка прав администратора
          if (!authProvider.isAdmin) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Доступ запрещен',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Требуются права администратора',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (normsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (normsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки норм',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    normsProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => normsProvider.loadNorms(context),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Управление нормами анализов',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Всего норм: ${normsProvider.norms.length}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddNormDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  ],
                ),
              ),

              // Список норм
              Expanded(
                child: normsProvider.norms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Нормы не загружены',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Нажмите кнопку обновления или добавьте новую норму',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => normsProvider.loadNorms(context),
                              child: const Text('Обновить'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => normsProvider.loadNorms(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: normsProvider.norms.length,
                          itemBuilder: (context, index) {
                            final norm = normsProvider.norms[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: Icon(
                                    Icons.science,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                title: Text(
                                  norm.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Норма: ${norm.minValue} - ${norm.maxValue} ${norm.unit}'),
                                    Text('ID: ${norm.id}'),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditNormDialog(context, norm);
                                    } else if (value == 'delete') {
                                      _showDeleteNormConfirmation(context, norm);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit),
                                          SizedBox(width: 8),
                                          Text('Редактировать'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Удалить', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddNormDialog(BuildContext context) {
    final nameController = TextEditingController();
    final minController = TextEditingController();
    final maxController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить норму'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название анализа',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Минимум',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Максимум',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Единица измерения',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  minController.text.isEmpty ||
                  maxController.text.isEmpty ||
                  unitController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Заполните все поля'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final minValue = double.tryParse(minController.text);
              final maxValue = double.tryParse(maxController.text);

              if (minValue == null || maxValue == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Введите корректные числовые значения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (minValue >= maxValue) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Минимальное значение должно быть меньше максимального'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final normsProvider = context.read<NormsProvider>();
              final norm = Norm(
                id: 0, // Будет установлен сервером
                name: nameController.text,
                minValue: minValue,
                maxValue: maxValue,
                unit: unitController.text,
              );

              final success = await normsProvider.addNorm(context, norm);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Норма успешно добавлена'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showEditNormDialog(BuildContext context, dynamic norm) {
    final nameController = TextEditingController(text: norm.name);
    final minController = TextEditingController(text: norm.minValue.toString());
    final maxController = TextEditingController(text: norm.maxValue.toString());
    final unitController = TextEditingController(text: norm.unit);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать норму'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название анализа',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Минимум',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Максимум',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Единица измерения',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  minController.text.isEmpty ||
                  maxController.text.isEmpty ||
                  unitController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Заполните все поля'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final minValue = double.tryParse(minController.text);
              final maxValue = double.tryParse(maxController.text);

              if (minValue == null || maxValue == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Введите корректные числовые значения'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (minValue >= maxValue) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Минимальное значение должно быть меньше максимального'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final normsProvider = context.read<NormsProvider>();
              final updatedNorm = Norm(
                id: norm.id,
                name: nameController.text,
                minValue: minValue,
                maxValue: maxValue,
                unit: unitController.text,
              );

              final success = await normsProvider.updateNorm(context, updatedNorm);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Норма успешно обновлена'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteNormConfirmation(BuildContext context, dynamic norm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление нормы'),
        content: Text(
          'Вы уверены, что хотите удалить норму "${norm.name}"? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final normsProvider = context.read<NormsProvider>();
              final success = await normsProvider.deleteNorm(context, norm.id);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Норма успешно удалена'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
} 