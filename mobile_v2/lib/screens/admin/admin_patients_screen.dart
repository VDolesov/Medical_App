import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class AdminPatientsScreen extends StatefulWidget {
  const AdminPatientsScreen({super.key});

  @override
  State<AdminPatientsScreen> createState() => _AdminPatientsScreenState();
}

class _AdminPatientsScreenState extends State<AdminPatientsScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  Timer? _searchTimer;

  Map<String, String> _headers() {
    final t = context.read<AuthProvider>().token;
    return {
      if (t != null) 'Authorization': 'Bearer $t',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDoctors();
      await _load();
    });
  }

  Future<void> _loadDoctors() async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/doctors'), headers: _headers());
      if (r.statusCode == 200) {
        final body = json.decode(utf8.decode(r.bodyBytes));
        if (body is List) {
          _doctors = body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final qs = _query.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(_query)}';
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/patients?page=0&size=50$qs'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        final body = json.decode(utf8.decode(r.bodyBytes));
        final list = body is Map ? body['content'] : body;
        if (list is List) {
          _items = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else {
        _error = 'HTTP ${r.statusCode}';
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _searchTimer?.cancel();
    _query = v.trim();
    _searchTimer = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _setAttending(int patientId, int? doctorUserId) async {
    final body = json.encode({'user_id': doctorUserId});
    final r = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/admin/patients/$patientId/attending-doctor'),
      headers: _headers(),
      body: body,
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(doctorUserId == null ? 'Пациент откреплён' : 'Закреплён за врачом')),
      );
    } else {
      try {
        final m = json.decode(utf8.decode(r.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m['error']?.toString() ?? 'HTTP ${r.statusCode}')));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('HTTP ${r.statusCode}')));
      }
    }
  }

  Future<void> _pickDoctor(Map<String, dynamic> patient) async {
    final currentDoctorId = (patient['attending_doctor_user_id'] as num?)?.toInt();
    final patientId = (patient['id'] as num).toInt();
    final picked = await showModalBottomSheet<_DoctorPick>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Text('Закрепить за врачом', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.no_accounts_outlined),
                      title: const Text('Открепить (свободный)'),
                      onTap: () => Navigator.pop(ctx, const _DoctorPick(null)),
                    ),
                    const Divider(height: 1),
                    ..._doctors.map((d) {
                      final id = (d['id'] as num).toInt();
                      final selected = id == currentDoctorId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          foregroundColor: Colors.teal.shade700,
                          child: const Icon(Icons.medical_services),
                        ),
                        title: Text(d['label']?.toString() ?? d['username']?.toString() ?? '?'),
                        subtitle: Text('@${d['username']}'),
                        trailing: selected ? const Icon(Icons.check, color: Colors.teal) : null,
                        onTap: () => Navigator.pop(ctx, _DoctorPick(id)),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _setAttending(patientId, picked.doctorId);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пациенты'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по коду пациента',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const LoadingIndicator();
    if (_error != null && _items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: _error,
        actionLabel: 'Повторить',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(icon: Icons.groups_outlined, title: 'Ничего не найдено');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _PatientTile(
          patient: _items[i],
          onChangeDoctor: () => _pickDoctor(_items[i]),
        ),
      ),
    );
  }
}

class _DoctorPick {
  final int? doctorId;
  const _DoctorPick(this.doctorId);
}

String _initials(String code) {
  final s = code.trim();
  if (s.isEmpty) return '?';
  if (s.length <= 2) return s.toUpperCase();
  if (s.startsWith('P-') && s.length >= 4) return s.substring(2, 4);
  return s.substring(0, 2).toUpperCase();
}

class _PatientTile extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onChangeDoctor;

  const _PatientTile({required this.patient, required this.onChangeDoctor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = patient['code']?.toString() ?? '?';
    final attLabel = patient['attending_doctor_label']?.toString();
    final hasApp = patient['has_app_account'] == true;
    final lkName = patient['lk_user_name']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: hasApp ? scheme.primaryContainer : scheme.surfaceContainerHigh,
              foregroundColor: hasApp ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              child: Text(_initials(code),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(code, style: Theme.of(context).textTheme.titleMedium)),
                      if (hasApp)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ЛК',
                              style: TextStyle(
                                  color: scheme.onTertiaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (patient['age'] != null) 'возраст ${patient['age']}',
                      if (patient['gender'] != null && patient['gender'].toString().isNotEmpty)
                        patient['gender'].toString(),
                      if (lkName != null && lkName.isNotEmpty) 'ЛК: $lkName',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: attLabel == null ? scheme.surfaceContainerHigh : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      attLabel == null ? 'Свободен' : 'Врач: $attLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: attLabel == null ? scheme.onSurfaceVariant : scheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Изменить врача',
              onPressed: onChangeDoctor,
            ),
          ],
        ),
      ),
    );
  }
}
