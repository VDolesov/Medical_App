import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class AdminPatientsScreen extends StatefulWidget {
  const AdminPatientsScreen({super.key});

  @override
  State<AdminPatientsScreen> createState() => _AdminPatientsScreenState();
}

class _AdminPatientsScreenState extends State<AdminPatientsScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  bool _doctorsLoaded = false;
  int _page = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  Future<void> _ensureDoctors(AuthProvider auth) async {
    if (_doctorsLoaded) return;
    final doctorsRes = await http.get(
      Uri.parse('$_baseUrl/admin/doctors'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json',
      },
    );
    if (doctorsRes.statusCode != 200) {
      throw Exception('Не удалось загрузить список врачей');
    }
    final doctorsJson = json.decode(doctorsRes.body) as List<dynamic>;
    _doctors = doctorsJson.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _doctorsLoaded = true;
  }

  Future<void> _loadPatients(AuthProvider auth) async {
    final pRes = await http.get(
      Uri.parse('$_baseUrl/admin/patients?page=$_page&size=50'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json',
      },
    );
    if (pRes.statusCode != 200) {
      throw Exception('Не удалось загрузить пациентов');
    }
    final body = json.decode(pRes.body) as Map<String, dynamic>;
    final content = body['content'] as List<dynamic>? ?? [];
    _patients = content.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _totalPages = body['totalPages'] is int ? body['totalPages'] as int : 1;
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null || !auth.isAdmin) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureDoctors(auth);
      await _loadPatients(auth);
    } catch (e) {
      _error = 'Ошибка: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadPatientsPageOnly() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null || !auth.isAdmin) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadPatients(auth);
    } catch (e) {
      _error = 'Ошибка: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setAttending(int patientId, int? doctorUserId) async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    final res = await http.patch(
      Uri.parse('$_baseUrl/admin/patients/$patientId/attending-doctor'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json',
      },
      body: json.encode({'user_id': doctorUserId}),
    );

    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено')),
      );
      await _loadPatientsPageOnly();
    } else {
      String msg = 'Ошибка сохранения';
      try {
        final m = json.decode(res.body);
        if (m is Map && m['error'] != null) msg = m['error'].toString();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Пациенты')),
        body: const Center(child: Text('Доступ запрещён')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пациенты и врачи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _page > 0
                                ? () {
                                    setState(() => _page--);
                                    _loadPatientsPageOnly();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Стр. ${_page + 1} / $_totalPages'),
                          IconButton(
                            onPressed: _page + 1 < _totalPages
                                ? () {
                                    setState(() => _page++);
                                    _loadPatientsPageOnly();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _patients.length,
                        itemBuilder: (context, i) {
                          final p = _patients[i];
                          final id = p['id'] is int ? p['id'] as int : int.parse(p['id'].toString());
                          final code = p['code']?.toString() ?? '';
                          final attId = p['attending_doctor_user_id'];
                          int? currentDoctorId;
                          if (attId is int) {
                            currentDoctorId = attId;
                          } else if (attId != null) {
                            currentDoctorId = int.tryParse(attId.toString());
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    p['attending_doctor_label']?.toString().isNotEmpty == true
                                        ? 'Сейчас: ${p['attending_doctor_label']}'
                                        : 'Не закреплён',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int?>(
                                    isExpanded: true,
                                    value: currentDoctorId,
                                    decoration: const InputDecoration(
                                      labelText: 'Ведущий врач',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Не назначен'),
                                      ),
                                      ..._doctors.map((d) {
                                        final did = d['id'] is int ? d['id'] as int : int.parse(d['id'].toString());
                                        final label = d['label']?.toString() ?? d['username']?.toString() ?? '$did';
                                        return DropdownMenuItem<int?>(
                                          value: did,
                                          child: Text(label, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ],
                                    onChanged: (v) => _setAttending(id, v),
                                  ),
                                ],
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
