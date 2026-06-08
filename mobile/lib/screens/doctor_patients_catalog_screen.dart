import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class DoctorPatientsCatalogScreen extends StatefulWidget {
  const DoctorPatientsCatalogScreen({super.key});

  @override
  State<DoctorPatientsCatalogScreen> createState() => _DoctorPatientsCatalogScreenState();
}

class _DoctorPatientsCatalogScreenState extends State<DoctorPatientsCatalogScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final _qController = TextEditingController();

  @override
  void dispose() {
    _qController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = _qController.text.trim();
      final uri = Uri.parse('$_baseUrl/doctor/patients').replace(queryParameters: {
        'page': '0',
        'size': '100',
        if (q.isNotEmpty) 'q': q,
      });
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить список';
        });
        return;
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final content = body['content'] as List<dynamic>? ?? [];
      _items = content.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'free':
        return 'Свободен';
      case 'mine':
        return 'Мой пациент';
      case 'other_doctor':
        return 'У другого врача';
      case 'admin':
        return 'Админ';
      default:
        return s ?? '—';
    }
  }

  Color? _statusColor(String? s) {
    switch (s) {
      case 'free':
        return Colors.grey;
      case 'mine':
        return Colors.green;
      case 'other_doctor':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isDoctor && !auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Пациенты')),
        body: const Center(child: Text('Доступ только для врача или администратора')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник пациентов'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по коду',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _load, child: const Text('Найти')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('Нет записей'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final p = _items[i];
                              final code = p['code']?.toString() ?? '';
                              final st = p['viewer_status']?.toString();
                              final att = p['attending_doctor_label']?.toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: att != null && att.isNotEmpty
                                      ? Text('Врач: $att')
                                      : const Text('Не закреплён'),
                                  trailing: Chip(
                                    label: Text(_statusLabel(st), style: const TextStyle(fontSize: 12)),
                                    backgroundColor: _statusColor(st)?.withOpacity(0.2),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
