import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _fileName;
  List<int>? _bytes;
  bool _uploading = false;
  String? _result;

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    setState(() {
      _fileName = f.name;
      _bytes = f.bytes;
      _result = null;
    });
  }

  Future<void> _upload() async {
    if (_bytes == null || _fileName == null) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _uploading = true;
      _result = null;
    });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer ${auth.token}'
        ..files.add(http.MultipartFile.fromBytes('file', _bytes!, filename: _fileName));
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        _result = 'Загружено. Отчёт появится в списке.';
        if (mounted) {
          await context.read<ReportsProvider>().loadList(isPatient: auth.isPatient, isAdmin: auth.isAdmin);
        }
      } else {
        _result = 'Ошибка: ${streamed.statusCode}. $body';
      }
    } catch (e) {
      _result = 'Сеть: $e';
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Загрузка Excel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Card(
              color: scheme.primaryContainer.withOpacity(0.45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text('Формат файла', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'XLSX с обязательными колонками «Код пациента», «Возраст». '
                      'Дополнительно поддерживаются столбцы маркеров (ТТГ, кальцитонин, кальций, паратгормон…) и клинический контекст (TNM, Bethesda, операция).',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _picker(scheme),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _bytes == null || _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_uploading ? 'Загружаем…' : 'Загрузить'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 14),
              Card(
                color: scheme.secondaryContainer.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(_result!.startsWith('Загруж') ? Icons.check_circle : Icons.error_outline,
                          color: _result!.startsWith('Загруж') ? scheme.tertiary : scheme.error),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_result!)),
                      if (_result!.startsWith('Загруж'))
                        TextButton(
                          onPressed: () => context.go('/reports'),
                          child: const Text('К отчётам'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _picker(ColorScheme scheme) {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withOpacity(0.6),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.file_upload_outlined, color: scheme.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName ?? 'Выбрать файл',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(_fileName == null ? 'XLSX до 50 МБ' : '${(_bytes?.length ?? 0) ~/ 1024} КБ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
