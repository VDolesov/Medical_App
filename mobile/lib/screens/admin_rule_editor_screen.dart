import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/admin_knowledge_provider.dart';
import '../providers/auth_provider.dart';

class AdminRuleEditorScreen extends StatefulWidget {
  final int? id;

  const AdminRuleEditorScreen({super.key, this.id});

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
  final _actionJsonCtrl = TextEditingController(text: '{}');

  String _severity = 'INFO';
  String _category = 'FOLLOW_UP';
  int? _sourceId;
  bool _active = true;

  late _CondNode _root;
  bool _saving = false;
  String? _formError;

  bool get _isCreate => widget.id == null;

  @override
  void initState() {
    super.initState();
    _root = _CondNode.empty(kind: _CondKind.allGroup);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final provider = context.read<AdminKnowledgeProvider>();
      if (provider.rules.isEmpty || provider.sources.isEmpty) {
        await provider.loadAll(auth);
      }
      if (!_isCreate) {
        final r = provider.rules.firstWhere(
          (x) => (x['id'] as num?)?.toInt() == widget.id,
          orElse: () => <String, dynamic>{},
        );
        if (r.isNotEmpty && mounted) {
          _hydrateFromRule(r);
        }
      }
    });
  }

  void _hydrateFromRule(Map<String, dynamic> r) {
    _codeCtrl.text = r['code']?.toString() ?? '';
    _titleCtrl.text = r['title']?.toString() ?? '';
    _rationaleCtrl.text = r['rationale']?.toString() ?? '';
    _patientMsgCtrl.text = r['patientMessage']?.toString() ?? '';
    _sourceSectionCtrl.text = r['sourceSection']?.toString() ?? '';
    _priorityCtrl.text = (r['priority']?.toString() ?? '100');
    _severity = (r['severity']?.toString() ?? 'INFO').toUpperCase();
    _category = (r['category']?.toString() ?? 'FOLLOW_UP');
    _active = r['active'] == true;
    final sources = context.read<AdminKnowledgeProvider>().sources;
    final srcCode = r['sourceCode']?.toString();
    if (srcCode != null) {
      final match = sources.firstWhere(
        (s) => s['code'] == srcCode,
        orElse: () => <String, dynamic>{},
      );
      _sourceId = (match['id'] as num?)?.toInt();
    }
    final cond = r['conditionJson'];
    if (cond is Map) {
      _root = _CondNode.fromJson(Map<String, dynamic>.from(cond));
    }
    final action = r['actionJson'];
    _actionJsonCtrl.text = action is Map
        ? const JsonEncoder.withIndent('  ').convert(action)
        : '{}';
    setState(() {});
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    _rationaleCtrl.dispose();
    _patientMsgCtrl.dispose();
    _sourceSectionCtrl.dispose();
    _priorityCtrl.dispose();
    _actionJsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
      _saving = true;
    });
    try {
      final code = _codeCtrl.text.trim();
      final title = _titleCtrl.text.trim();
      if (_isCreate && code.isEmpty) {
        throw 'Заполните «Код правила»';
      }
      if (title.isEmpty) {
        throw 'Заполните «Заголовок»';
      }

      Map<String, dynamic>? action;
      try {
        final raw = _actionJsonCtrl.text.trim();
        if (raw.isEmpty || raw == '{}') {
          action = <String, dynamic>{};
        } else {
          final decoded = json.decode(raw);
          if (decoded is! Map) throw 'JSON действия должен быть объектом';
          action = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        throw 'JSON действия некорректен: $e';
      }

      final cond = _root.toJson();
      if (cond == null) {
        throw 'Условие не заполнено';
      }

      final body = <String, dynamic>{
        'title': title,
        'severity': _severity,
        'category': _category,
        'priority': int.tryParse(_priorityCtrl.text.trim()) ?? 100,
        'active': _active,
        'rationale': _rationaleCtrl.text.trim(),
        'patientMessage': _patientMsgCtrl.text.trim().isEmpty ? null : _patientMsgCtrl.text.trim(),
        'sourceId': _sourceId,
        'sourceSection': _sourceSectionCtrl.text.trim().isEmpty ? null : _sourceSectionCtrl.text.trim(),
        'conditionJson': cond,
        'actionJson': action,
      };
      if (_isCreate) {
        body['code'] = code;
      }

      final auth = context.read<AuthProvider>();
      final provider = context.read<AdminKnowledgeProvider>();
      final err = _isCreate
          ? await provider.createRule(auth, body)
          : await provider.updateRule(auth, widget.id!, body);
      if (err != null) {
        throw err;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isCreate ? 'Правило создано' : 'Правило обновлено')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _formError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Новое правило' : 'Редактирование правила'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Сохранить', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Consumer<AdminKnowledgeProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_formError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(_formError!, style: TextStyle(color: Colors.red.shade800)),
                  ),
                  const SizedBox(height: 12),
                ],
                _section('Основное'),
                TextField(
                  controller: _codeCtrl,
                  enabled: _isCreate,
                  decoration: const InputDecoration(
                    labelText: 'Код (например, R-013)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Заголовок',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _severity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                    Text(_active ? 'Active' : 'Off', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _knownCategories.contains(_category) ? _category : null,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: _knownCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'FOLLOW_UP'),
                ),
                const SizedBox(height: 16),
                _section('Источник (клинические рекомендации)'),
                DropdownButtonFormField<int?>(
                  value: _sourceId,
                  decoration: const InputDecoration(
                    labelText: 'Источник',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('— не указан —')),
                    ...provider.sources.map((s) {
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
                  decoration: const InputDecoration(
                    labelText: 'Раздел источника (например, «Раздел 8»)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _section('Обоснование'),
                TextField(
                  controller: _rationaleCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Обоснование (для врача)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _patientMsgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Сообщение пациенту (мягкая формулировка)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _section('Условие срабатывания'),
                _ConditionNodeEditor(
                  node: _root,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
                _section('Действие при срабатывании (JSON)'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _actionJsonCtrl,
                    maxLines: 10,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '{\n  "verdict": "...",\n  "recommendations": ["..."]\n}',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Подсказка: ключи verdict (строка), recommendations (массив строк), tsh_target {min, max}, tags (массив строк).',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(_isCreate ? 'Создать' : 'Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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

enum _CondKind { allGroup, anyGroup, notGroup, leaf }

class _CondNode {
  _CondKind kind;
  List<_CondNode> children = [];
  _CondNode? notInner;

String feature = 'tsh_post';
  String op = 'eq';
  String valueText = '';

  _CondNode({required this.kind});

  factory _CondNode.empty({required _CondKind kind}) {
    final n = _CondNode(kind: kind);
    if (kind == _CondKind.allGroup || kind == _CondKind.anyGroup) {
      n.children.add(_CondNode.empty(kind: _CondKind.leaf));
    } else if (kind == _CondKind.notGroup) {
      n.notInner = _CondNode.empty(kind: _CondKind.leaf);
    }
    return n;
  }

  factory _CondNode.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('all')) {
      final n = _CondNode(kind: _CondKind.allGroup);
      final list = json['all'];
      if (list is List) {
        for (final c in list) {
          if (c is Map) {
            n.children.add(_CondNode.fromJson(Map<String, dynamic>.from(c)));
          }
        }
      }
      return n;
    }
    if (json.containsKey('any')) {
      final n = _CondNode(kind: _CondKind.anyGroup);
      final list = json['any'];
      if (list is List) {
        for (final c in list) {
          if (c is Map) {
            n.children.add(_CondNode.fromJson(Map<String, dynamic>.from(c)));
          }
        }
      }
      return n;
    }
    if (json.containsKey('not')) {
      final n = _CondNode(kind: _CondKind.notGroup);
      final inner = json['not'];
      if (inner is Map) {
        n.notInner = _CondNode.fromJson(Map<String, dynamic>.from(inner));
      }
      return n;
    }
    final n = _CondNode(kind: _CondKind.leaf);
    n.feature = json['feature']?.toString() ?? 'tsh_post';
    n.op = json['op']?.toString() ?? 'eq';
    if (json.containsKey('values')) {
      n.valueText = (json['values'] as List).map((e) => e.toString()).join(',');
    } else if (json.containsKey('value')) {
      n.valueText = json['value'].toString();
    }
    return n;
  }

Map<String, dynamic>? toJson() {
    switch (kind) {
      case _CondKind.allGroup:
      case _CondKind.anyGroup:
        final list = children.map((c) => c.toJson()).whereType<Map<String, dynamic>>().toList();
        if (list.isEmpty) return null;
        return {kind == _CondKind.allGroup ? 'all' : 'any': list};
      case _CondKind.notGroup:
        final inner = notInner?.toJson();
        if (inner == null) return null;
        return {'not': inner};
      case _CondKind.leaf:
        final m = <String, dynamic>{'feature': feature, 'op': op};
        if (op == 'present' || op == 'absent') {
          return m;
        }
        if (op == 'in' || op == 'not_in') {
          final parts = valueText.split(',').map((s) => _parseScalar(s.trim())).where((v) => v != null).toList();
          if (parts.isEmpty) return null;
          m['values'] = parts;
          return m;
        }
        if (op == 'range' || op == 'out_of_range') {
          final parts = valueText.split(',').map((s) => _parseScalar(s.trim())).whereType<num>().toList();
          if (parts.length != 2) return null;
          m['values'] = parts;
          return m;
        }
        final v = _parseScalar(valueText.trim());
        if (v == null) return null;
        m['value'] = v;
        return m;
    }
  }

  static dynamic _parseScalar(String s) {
    if (s.isEmpty) return null;
    if (s == 'true') return true;
    if (s == 'false') return false;
    final n = num.tryParse(s);
    if (n != null) return n;
    return s;
  }
}

class _ConditionNodeEditor extends StatelessWidget {
  final _CondNode node;
  final VoidCallback onChanged;

  const _ConditionNodeEditor({required this.node, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = switch (node.kind) {
      _CondKind.allGroup => Colors.indigo,
      _CondKind.anyGroup => Colors.teal,
      _CondKind.notGroup => Colors.red,
      _CondKind.leaf => Colors.grey,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<_CondKind>(
                value: node.kind,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: _CondKind.allGroup, child: Text('ALL (и)')),
                  DropdownMenuItem(value: _CondKind.anyGroup, child: Text('ANY (или)')),
                  DropdownMenuItem(value: _CondKind.notGroup, child: Text('NOT')),
                  DropdownMenuItem(value: _CondKind.leaf, child: Text('Условие')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  if (v == _CondKind.allGroup || v == _CondKind.anyGroup) {
                    if (node.kind != _CondKind.allGroup && node.kind != _CondKind.anyGroup) {
                      node.children = [_CondNode.empty(kind: _CondKind.leaf)];
                    }
                  } else if (v == _CondKind.notGroup) {
                    node.notInner ??= _CondNode.empty(kind: _CondKind.leaf);
                    node.children = [];
                  } else if (v == _CondKind.leaf) {
                    node.children = [];
                    node.notInner = null;
                  }
                  node.kind = v;
                  onChanged();
                },
              ),
              const Spacer(),
              if (node.kind == _CondKind.allGroup || node.kind == _CondKind.anyGroup)
                IconButton(
                  tooltip: 'Добавить под-условие',
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    node.children.add(_CondNode.empty(kind: _CondKind.leaf));
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (node.kind == _CondKind.leaf)
            _LeafEditor(node: node, onChanged: onChanged),
          if (node.kind == _CondKind.allGroup || node.kind == _CondKind.anyGroup)
            ...List.generate(node.children.length, (i) {
              final child = node.children[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ConditionNodeEditor(node: child, onChanged: onChanged)),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                    tooltip: 'Удалить',
                    onPressed: node.children.length > 1
                        ? () {
                            node.children.removeAt(i);
                            onChanged();
                          }
                        : null,
                  ),
                ],
              );
            }),
          if (node.kind == _CondKind.notGroup && node.notInner != null)
            _ConditionNodeEditor(node: node.notInner!, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LeafEditor extends StatefulWidget {
  final _CondNode node;
  final VoidCallback onChanged;

  const _LeafEditor({required this.node, required this.onChanged});

  @override
  State<_LeafEditor> createState() => _LeafEditorState();
}

class _LeafEditorState extends State<_LeafEditor> {
  late final TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _valueCtrl = TextEditingController(text: widget.node.valueText);
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  static const _features = <String>[
    'age', 'gender',
    'operation_type', 'disease_duration_months', 'hospital_stay_days', 'bethesda',
    'tnm_t_pre', 'tnm_n_pre', 'tnm_m_pre',
    'tnm_t_post', 'tnm_n_post', 'tnm_m_post',
    'alp_pre', 'calcium_pre', 'tsh_pre', 't4_free_pre',
    'calcitonin_pre', 'parathyroid_pre', 'antibody_to_tg_pre', 'cea_pre',
    'alp_post', 'calcium_post', 'tsh_post', 't4_free_post',
    'calcitonin_post', 'parathyroid_post', 'antibody_to_tg_post', 'cea_post',
    'calcitonin_delta', 'antibody_to_tg_delta', 'cea_delta', 'tsh_delta',
    'comorbidity_cv', 'comorbidity_gi', 'comorbidity_resp',
  ];

  static const _ops = <String, String>{
    'eq': '= (равно)',
    'neq': '≠ (не равно)',
    'gt': '> (больше)',
    'gte': '≥',
    'lt': '< (меньше)',
    'lte': '≤',
    'in': 'in (один из)',
    'not_in': 'not in',
    'range': 'в диапазоне',
    'out_of_range': 'вне диапазона',
    'present': 'значение задано',
    'absent': 'значение отсутствует',
  };

  bool get _hasValue => !(widget.node.op == 'present' || widget.node.op == 'absent');
  bool get _isListValue =>
      widget.node.op == 'in' || widget.node.op == 'not_in' ||
      widget.node.op == 'range' || widget.node.op == 'out_of_range';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: _features.contains(widget.node.feature) ? widget.node.feature : null,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Показатель',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _features
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    widget.node.feature = v;
                    widget.onChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: widget.node.op,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Оператор',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _ops.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      widget.node.op = v;
                    });
                    widget.onChanged();
                  }
                },
              ),
            ),
          ],
        ),
        if (_hasValue) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _valueCtrl,
            decoration: InputDecoration(
              labelText: _isListValue
                  ? (widget.node.op == 'range' || widget.node.op == 'out_of_range'
                      ? 'Диапазон через запятую (например, 0.1,0.5)'
                      : 'Значения через запятую (например, T1,T2,Nx)')
                  : 'Значение',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              widget.node.valueText = v;
              widget.onChanged();
            },
          ),
        ],
      ],
    );
  }
}
