import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/condition_builder.dart';

class AdminRuleEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRule;
  const AdminRuleEditorScreen({super.key, this.initialRule});

  @override
  State<AdminRuleEditorScreen> createState() => _AdminRuleEditorScreenState();
}

class _AdminRuleEditorScreenState extends State<AdminRuleEditorScreen> {
  final _codeCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _rationaleCtrl = TextEditingController();
  final _patientMsgCtrl = TextEditingController();
  final _sourceSectionCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController(text: '100');
  final _actionCtrl = TextEditingController(text: '{}');

  String _severity = 'INFO';
  String _category = 'FOLLOW_UP';
  int? _sourceId;
  bool _active = true;
  bool _saving = false;
  String? _err;

  late CondNode _cond;
  bool _conditionAsJson = false;
  late final TextEditingController _conditionJsonCtrl;

  List<Map<String, dynamic>> _sources = [];

  bool get _isCreate => widget.initialRule == null;

  @override
  void initState() {
    super.initState();
    _cond = CondNode.empty();
    _conditionJsonCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(_cond.toJson() ?? {}),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSources();
      if (widget.initialRule != null) _hydrate(widget.initialRule!);
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSources() async {
    final auth = context.read<AuthProvider>();
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/expert/sources'),
        headers: {
          if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );
      if (r.statusCode == 200) {
        final body = json.decode(utf8.decode(r.bodyBytes));
        if (body is List) {
          _sources = body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
  }

  void _hydrate(Map<String, dynamic> r) {
    _codeCtrl.text = r['code']?.toString() ?? '';
    _titleCtrl.text = r['title']?.toString() ?? '';
    _rationaleCtrl.text = r['rationale']?.toString() ?? '';
    _patientMsgCtrl.text = r['patientMessage']?.toString() ?? '';
    _sourceSectionCtrl.text = r['sourceSection']?.toString() ?? '';
    _priorityCtrl.text = (r['priority']?.toString() ?? '100');
    _severity = (r['severity']?.toString() ?? 'INFO').toUpperCase();
    _category = (r['category']?.toString() ?? 'FOLLOW_UP');
    _active = r['active'] == true || r['isActive'] == true;
    final scode = r['sourceCode']?.toString();
    if (scode != null) {
      final m = _sources.firstWhere((s) => s['code'] == scode, orElse: () => const {});
      _sourceId = (m['id'] as num?)?.toInt();
    }
    final cond = r['conditionJson'];
    if (cond is Map) {
      _cond = CondNode.fromJson(Map<String, dynamic>.from(cond));
      _conditionJsonCtrl.text = const JsonEncoder.withIndent('  ').convert(cond);
    }
    final act = r['actionJson'];
    _actionCtrl.text = act is Map ? const JsonEncoder.withIndent('  ').convert(act) : '{}';
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    _rationaleCtrl.dispose();
    _patientMsgCtrl.dispose();
    _sourceSectionCtrl.dispose();
    _priorityCtrl.dispose();
    _actionCtrl.dispose();
    _conditionJsonCtrl.dispose();
    super.dispose();
  }

  void _switchConditionMode(bool toJson) {
    if (toJson) {
      final j = _cond.toJson();
      _conditionJsonCtrl.text = const JsonEncoder.withIndent('  ').convert(j ?? {});
    } else {
      try {
        final raw = _conditionJsonCtrl.text.trim();
        if (raw.isEmpty || raw == '{}') {
          _cond = CondNode.empty();
        } else {
          final decoded = json.decode(raw);
          if (decoded is Map<String, dynamic>) {
            _cond = CondNode.fromJson(decoded);
          }
        }
        _err = null;
      } catch (e) {
        _err = 'Невалидный JSON условия: $e';
      }
    }
    setState(() => _conditionAsJson = toJson);
  }

  Future<void> _save() async {
    setState(() {
      _err = null;
      _saving = true;
    });
    try {
      if (_isCreate && _codeCtrl.text.trim().isEmpty) throw 'Код правила обязателен';
      if (_titleCtrl.text.trim().isEmpty) throw 'Заголовок обязателен';

      late final Map<String, dynamic> cond;
      if (_conditionAsJson) {
        try {
          final v = json.decode(_conditionJsonCtrl.text);
          if (v is! Map) throw 'condition должен быть JSON-объектом';
          cond = Map<String, dynamic>.from(v);
        } catch (e) {
          throw 'Условие — невалидный JSON: $e';
        }
      } else {
        final j = _cond.toJson();
        if (j == null) throw 'Условие не заполнено';
        cond = j;
      }

      Map<String, dynamic> act = {};
      try {
        final v = _actionCtrl.text.trim().isEmpty ? {} : json.decode(_actionCtrl.text);
        if (v is! Map) throw 'action должен быть JSON-объектом';
        act = Map<String, dynamic>.from(v);
      } catch (e) {
        throw 'Действие — невалидный JSON: $e';
      }

      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'severity': _severity,
        'category': _category,
        'priority': int.tryParse(_priorityCtrl.text.trim()) ?? 100,
        'active': _active,
        'rationale': _rationaleCtrl.text.trim(),
        'patientMessage': _patientMsgCtrl.text.trim().isEmpty ? null : _patientMsgCtrl.text.trim(),
        'sourceId': _sourceId,
        'sourceSection': _sourceSectionCtrl.text.trim().isEmpty ? null : _sourceSectionCtrl.text.trim(),
        'conditionJson': cond,
        'actionJson': act,
      };
      if (_isCreate) body['code'] = _codeCtrl.text.trim();

      final auth = context.read<AuthProvider>();
      final headers = {
        if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json; charset=utf-8',
      };
      final url = _isCreate
          ? '${ApiConfig.baseUrl}/admin/expert/rules'
          : '${ApiConfig.baseUrl}/admin/expert/rules/${widget.initialRule!['id']}';
      final r = _isCreate
          ? await http.post(Uri.parse(url), headers: headers, body: json.encode(body))
          : await http.put(Uri.parse(url), headers: headers, body: json.encode(body));
      if (r.statusCode != 200) {
        String msg = 'HTTP ${r.statusCode}';
        try {
          final m = json.decode(utf8.decode(r.bodyBytes));
          if (m is Map && m['error'] != null) msg = m['error'].toString();
        } catch (_) {}
        throw msg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isCreate ? 'Правило создано' : 'Правило обновлено')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Новое правило' : 'Редактирование правила'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_err != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_err!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            enabled: _isCreate,
            decoration: const InputDecoration(
              labelText: 'Код правила',
              hintText: 'например R-013',
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Заголовок', prefixIcon: Icon(Icons.title)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _severity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                    DropdownMenuItem(value: 'WARNING', child: Text('WARNING')),
                    DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL')),
                  ],
                  onChanged: (v) => setState(() => _severity = v ?? 'INFO'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _priorityCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
              const SizedBox(width: 6),
              Text(_active ? 'Активно' : 'Выключено'),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _knownCategories.contains(_category) ? _category : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: _knownCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _category = v ?? 'FOLLOW_UP'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _sourceId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Источник'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— не указан —')),
              ..._sources.map((s) {
                final id = (s['id'] as num?)?.toInt();
                return DropdownMenuItem<int?>(
                  value: id,
                  child: Text('${s['code']} · ${s['title']}', overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (v) => setState(() => _sourceId = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sourceSectionCtrl,
            decoration: const InputDecoration(labelText: 'Раздел источника (например, «Раздел 8»)'),
          ),
          const SizedBox(height: 18),
          Text('Обоснование', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _rationaleCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Для врача'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _patientMsgCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Для пациента (мягкая формулировка)'),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text('Условие срабатывания', style: Theme.of(context).textTheme.titleMedium),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Конструктор'), icon: Icon(Icons.account_tree_outlined)),
                  ButtonSegment(value: true, label: Text('JSON'), icon: Icon(Icons.code)),
                ],
                selected: {_conditionAsJson},
                onSelectionChanged: (s) => _switchConditionMode(s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_conditionAsJson)
            _jsonBox(controller: _conditionJsonCtrl, scheme: scheme, maxLines: 14)
          else
            ConditionNodeEditor(node: _cond, onChanged: () => setState(() {})),
          const SizedBox(height: 18),
          Text('Действие при срабатывании (JSON)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Поля verdict (строка), recommendations (массив строк), tags (массив), tsh_target { min, max }, next_visit_months.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _jsonBox(controller: _actionCtrl, scheme: scheme, maxLines: 8),
        ],
      ),
    );
  }

  Widget _jsonBox({required TextEditingController controller, required ColorScheme scheme, required int maxLines}) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  static const _knownCategories = [
    'RISK_STRATIFICATION',
    'FOLLOW_UP',
    'RECURRENCE_SUSPECT',
    'COMPLICATION',
    'DIFFERENTIAL_DIAGNOSIS',
    'THERAPY_ADJUSTMENT',
    'PREOP_RISK',
    'GENERAL',
  ];
}
