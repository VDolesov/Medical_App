import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );
      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка выбора файла: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите файл для загрузки'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final reportsProvider = context.read<ReportsProvider>();
      final success = await reportsProvider.uploadFile(context, _selectedFile!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл успешно загружен!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Очищаем выбранный файл
        setState(() {
          _selectedFile = null;
          _fileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузка файла'),
      ),
      body: Consumer2<AuthProvider, ReportsProvider>(
        builder: (context, authProvider, reportsProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Информационная карточка
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
                              'Информация о загрузке',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Загрузите Excel файл (.xlsx или .xls) с данными анализов пациентов. '
                          'Файл должен содержать следующие колонки:\n'
                          '• Код пациента\n'
                          '• Возраст\n'
                          '• Результаты анализов (Щелочная фосфатаза, Кальций общий, ТТГ и др.)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Выбор файла
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Выбор файла',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_selectedFile != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fileName ?? 'Файл выбран',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Размер: ${(_selectedFile!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _selectedFile = null;
                                      _fileName = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : _pickFile,
                            icon: const Icon(Icons.file_upload),
                            label: Text(_selectedFile == null ? 'Выбрать файл' : 'Выбрать другой файл'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Кнопка загрузки
                if (_selectedFile != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadFile,
                      icon: _isUploading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isUploading ? 'Загрузка...' : 'Загрузить файл'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Ошибки
                if (reportsProvider.error != null) ...[
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              reportsProvider.error!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => reportsProvider.clearError(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Пример структуры файла
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.table_chart,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Пример структуры файла',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Изображение с примером структуры файла
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Dialog(
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 600,
                                      maxHeight: 800,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppBar(
                                          title: const Text('Пример структуры файла'),
                                          backgroundColor: Colors.transparent,
                                          elevation: 0,
                                          actions: [
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () => Navigator.of(context).pop(),
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Image.asset(
                                              'assets/images/file_structure_example.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.image_not_supported,
                                                        size: 64,
                                                        color: Colors.grey,
                                                      ),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        'Изображение примера не найдено',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Добавьте файл file_structure_example.png\nв папку assets/images/',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.asset(
                                    'assets/images/file_structure_example.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Изображение примера не найдено',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'Добавьте файл file_structure_example.png\nв папку assets/images/',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.zoom_in,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Увеличить',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        const Text(
                          '• Первая строка — заголовки (названия колонок, обязательно!)\n'
                          '• Дальше — данные по каждому пациенту\n'
                          '• Можно добавлять любые анализы в отдельные колонки\n'
                          '• Поддерживаемые форматы: .xlsx, .xls',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


} 