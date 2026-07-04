import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class AdminNormsScreen extends StatefulWidget {
  const AdminNormsScreen({super.key});

  @override
  State<AdminNormsScreen> createState() => _AdminNormsScreenState();
}

class _AdminNormsScreenState extends State<AdminNormsScreen> {
  List<Map<String, dynamic>> _norms = [];
  bool _loading = false;
  String? _error;
  String _query = '';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/norms'), headers: _headers());
      if (r.statusCode == 200) {
        final body = json.decode(utf8.decode(r.bodyBytes));
        if (body is List) {
          _norms = body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          _norms.sort((a, b) => (a['name']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['name']?.toString() ?? '').toLowerCase()));
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

  Future<void> _delete(Map<String, dynamic> norm) async {
    final id = (norm['id'] as num).toInt();
    final messenger = ScaffoldMessenger.of(context);
    final headers = _headers();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить норму?'),
        content: Text('${norm['name']}\n\nЭто действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await http.delete(Uri.parse('${ApiConfig.baseUrl}/admin/norms/$id'), headers: headers);
    if (!mounted) return;
    if (r.statusCode == 200) {
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('Норма удалена')));
    } else {
      _toastError(messenger, r);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? norm}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _NormEditor(norm: norm), fullscreenDialog: true),
    );
    if (changed == true) await _load();
  }

  void _toastError(ScaffoldMessengerState messenger, http.Response r) {
    String msg = 'HTTP ${r.statusCode}';
    try {
      final m = json.decode(utf8.decode(r.bodyBytes));
      if (m is Map && m['error'] != null) msg = m['error'].toString();
    } catch (_) {}
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _norms
        : _norms.where((n) => (n['name']?.toString() ?? '').toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нормы анализов'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Новая'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: _body(filtered)),
        ],
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> filtered) {
    if (_loading && _norms.isEmpty) return const LoadingIndicator();
    if (_error != null && _norms.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: _error,
        actionLabel: 'Повторить',
        onAction: _load,
      );
    }
    if (filtered.isEmpty) {
      return const EmptyState(icon: Icons.straighten_outlined, title: 'Норм не найдено');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _NormTile(
          norm: filtered[i],
          onEdit: () => _openEditor(norm: filtered[i]),
          onDelete: () => _delete(filtered[i]),
        ),
      ),
    );
  }
}

String _fmtNumber(dynamic v) {
  if (v is num) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }
  return v?.toString() ?? '';
}

class _NormTile extends StatelessWidget {
  final Map<String, dynamic> norm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NormTile({required this.norm, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = norm['name']?.toString() ?? '?';
    final unit = norm['unit']?.toString() ?? '';
    final range =
        '${_fmtNumber(norm['min_value'])} – ${_fmtNumber(norm['max_value'])}${unit.isEmpty ? '' : ' $unit'}';
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.straighten),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Норма: $range',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Редактировать')])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Удалить', style: TextStyle(color: Colors.red))
                      ])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NormEditor extends StatefulWidget {
  final Map<String, dynamic>? norm;
  const _NormEditor({this.norm});

  @override
  State<_NormEditor> createState() => _NormEditorState();
}

class _NormEditorState extends State<_NormEditor> {
  final _name = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _unit = TextEditingController();
  bool _saving = false;
  String? _err;

  bool get _isCreate => widget.norm == null;

  @override
  void initState() {
    super.initState();
    final n = widget.norm;
    if (n != null) {
      _name.text = n['name']?.toString() ?? '';
      _min.text = _fmtNumber(n['min_value']);
      _max.text = _fmtNumber(n['max_value']);
      _unit.text = n['unit']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _max.dispose();
    _unit.dispose();
    super.dispose();
  }

  Map<String, String> _headers() {
    final t = context.read<AuthProvider>().token;
    return {
      if (t != null) 'Authorization': 'Bearer $t',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  double? _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  Future<void> _save() async {
    setState(() {
      _err = null;
      _saving = true;
    });
    try {
      final name = _name.text.trim();
      final unit = _unit.text.trim();
      final min = _parse(_min.text);
      final max = _parse(_max.text);
      if (name.isEmpty) throw 'Название обязательно';
      if (min == null) throw 'Минимум должен быть числом';
      if (max == null) throw 'Максимум должен быть числом';
      if (max < min) throw 'Максимум не может быть меньше минимума';
      if (unit.isEmpty) throw 'Единица измерения обязательна';

      final body = {'name': name, 'min_value': min, 'max_value': max, 'unit': unit};
      final http.Response r;
      if (_isCreate) {
        r = await http.post(Uri.parse('${ApiConfig.baseUrl}/admin/norms'),
            headers: _headers(), body: json.encode(body));
      } else {
        final id = (widget.norm!['id'] as num).toInt();
        r = await http.patch(Uri.parse('${ApiConfig.baseUrl}/admin/norms/$id'),
            headers: _headers(), body: json.encode(body));
      }
      if (r.statusCode != 200) throw _readError(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isCreate ? 'Норма добавлена' : 'Норма обновлена')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _readError(http.Response r) {
    try {
      final m = json.decode(utf8.decode(r.bodyBytes));
      if (m is Map && m['error'] != null) return m['error'].toString();
    } catch (_) {}
    return 'HTTP ${r.statusCode}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Новая норма' : 'Редактирование нормы'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Сохранить')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_err != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_err!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Название показателя', prefixIcon: Icon(Icons.science_outlined)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Минимум'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Максимум'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _unit,
            decoration: const InputDecoration(labelText: 'Единица измерения', prefixIcon: Icon(Icons.straighten)),
          ),
        ],
      ),
    );
  }
}
