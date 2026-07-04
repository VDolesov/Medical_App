import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class PickerPatientEntry {
  final int id;
  final String code;
  final int age;
  final String? gender;
  final bool hasAppAccount;
  final int? attendingDoctorUserId;
  final String? attendingDoctorLabel;
  final String viewerStatus;
  final String? lkUserName;

  PickerPatientEntry({
    required this.id,
    required this.code,
    required this.age,
    this.gender,
    required this.hasAppAccount,
    this.attendingDoctorUserId,
    this.attendingDoctorLabel,
    required this.viewerStatus,
    this.lkUserName,
  });

  factory PickerPatientEntry.fromJson(Map<String, dynamic> m) => PickerPatientEntry(
        id: (m['id'] as num).toInt(),
        code: m['code']?.toString() ?? '',
        age: (m['age'] as num?)?.toInt() ?? 0,
        gender: m['gender']?.toString(),
        hasAppAccount: m['has_app_account'] == true,
        attendingDoctorUserId: (m['attending_doctor_user_id'] as num?)?.toInt(),
        attendingDoctorLabel: m['attending_doctor_label']?.toString(),
        viewerStatus: m['viewer_status']?.toString() ?? 'free',
        lkUserName: m['lk_user_name']?.toString(),
      );

  String get displayName {
    final n = (lkUserName ?? '').trim();
    return n.isEmpty ? '—' : n;
  }
}

Future<String?> showPatientPicker(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.92,
      child: _PatientPickerSheet(),
    ),
  );
}

class _PatientPickerSheet extends StatefulWidget {
  const _PatientPickerSheet();

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  List<PickerPatientEntry> _items = [];
  bool _loading = false;
  String? _error;
  int _page = 0;
  bool _hasMore = true;
  String _scope = 'all';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Map<String, String> _headers() {
    final t = context.read<AuthProvider>().token;
    return {
      if (t != null) 'Authorization': 'Bearer $t',
      'Accept': 'application/json; charset=utf-8',
    };
  }

  Future<void> _reload() async {
    setState(() {
      _items = [];
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final q = _search.text.trim();
      final uri = Uri.parse('${ApiConfig.baseUrl}/doctor/patients').replace(queryParameters: {
        if (q.isNotEmpty) 'q': q,
        'page': '$_page',
        'size': '30',
      });
      final r = await http.get(uri, headers: _headers());
      if (!mounted) return;
      if (r.statusCode != 200) {
        setState(() => _error = 'HTTP ${r.statusCode}');
        return;
      }
      final body = json.decode(utf8.decode(r.bodyBytes));
      final list = (body['content'] as List? ?? const []);
      final parsed = list
          .whereType<Map>()
          .map((e) => PickerPatientEntry.fromJson(Map<String, dynamic>.from(e)))
          .where(_passesScope)
          .toList();
      setState(() {
        _items.addAll(parsed);
        _page += 1;
        final total = (body['totalPages'] as num?)?.toInt() ?? 0;
        _hasMore = _page < total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _passesScope(PickerPatientEntry e) {
    switch (_scope) {
      case 'free':
        return e.viewerStatus == 'free';
      case 'mine':
        return e.viewerStatus == 'mine';
      default:
        return true;
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Выбор пациента', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_outlined),
                  tooltip: 'Ввести код вручную',
                  onPressed: () => _enterCodeManually(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Фамилия, имя или код',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _reload();
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Все')),
                ButtonSegment(value: 'free', label: Text('Свободные')),
                ButtonSegment(value: 'mine', label: Text('Мои')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) {
                setState(() => _scope = s.first);
                _reload();
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _list(scheme)),
        ],
      ),
    );
  }

  Widget _list(ColorScheme scheme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                _search.text.isEmpty ? 'Пациенты не найдены' : 'Ничего не найдено по «${_search.text.trim()}»',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _PatientTile(
          entry: _items[i],
          onTap: () => Navigator.pop(context, _items[i].code),
        );
      },
    );
  }

  Future<void> _enterCodeManually(BuildContext rootContext) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String?>(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Код пациента'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'P-XXXXXXXX',
            prefixIcon: Icon(Icons.qr_code_2),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Привязать')),
        ],
      ),
    );
    if (!mounted) return;
    if (code != null && code.isNotEmpty) {
      Navigator.pop(context, code);
    }
  }
}

class _PatientTile extends StatelessWidget {
  final PickerPatientEntry entry;
  final VoidCallback onTap;

  const _PatientTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusInfo(entry.viewerStatus, scheme);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(
                  _initials(entry),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.code}  ·  ${entry.age} лет${entry.gender != null && entry.gender!.isNotEmpty ? '  ·  ${entry.gender}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (entry.viewerStatus == 'other_doctor' && entry.attendingDoctorLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Закреплён: ${entry.attendingDoctorLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(color: status.fg, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(PickerPatientEntry e) {
    final n = e.lkUserName?.trim() ?? '';
    if (n.isEmpty) {
      final c = e.code;
      if (c.length >= 4) return c.substring(2, 4).toUpperCase();
      return c.toUpperCase();
    }
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  _StatusInfo _statusInfo(String s, ColorScheme scheme) {
    switch (s) {
      case 'mine':
        return _StatusInfo('Мой', scheme.primaryContainer, scheme.onPrimaryContainer);
      case 'other_doctor':
        return _StatusInfo('Закреплён', scheme.errorContainer, scheme.onErrorContainer);
      case 'admin':
        return _StatusInfo('Админ', scheme.tertiaryContainer, scheme.onTertiaryContainer);
      case 'free':
      default:
        return _StatusInfo('Свободный', scheme.secondaryContainer, scheme.onSecondaryContainer);
    }
  }
}

class _StatusInfo {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusInfo(this.label, this.bg, this.fg);
}
