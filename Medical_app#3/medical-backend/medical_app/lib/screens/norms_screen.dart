import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/norms_provider.dart';

class NormsScreen extends StatefulWidget {
  const NormsScreen({Key? key}) : super(key: key);

  @override
  State<NormsScreen> createState() => _NormsScreenState();
}

class _NormsScreenState extends State<NormsScreen> {
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
        title: const Text('Нормы анализов'),
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
      body: Consumer<NormsProvider>(
        builder: (context, normsProvider, child) {
          if (normsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (normsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('Ошибка загрузки норм', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(normsProvider.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => normsProvider.loadNorms(context),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          if (normsProvider.norms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Нормы не найдены', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Обратитесь к администратору для добавления норм', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: normsProvider.norms.length,
            itemBuilder: (context, index) {
              final norm = normsProvider.norms[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.science, color: Colors.green.shade700),
                  ),
                  title: Text(norm.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Норма: \\${norm.minValue} - \\${norm.maxValue} \\${norm.unit}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 