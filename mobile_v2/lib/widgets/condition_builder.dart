import 'package:flutter/material.dart';

enum CondKind { allGroup, anyGroup, notGroup, leaf }

class CondNode {
  CondKind kind;
  List<CondNode> children;
  CondNode? notInner;

  String feature;
  String op;
  String valueText;

  CondNode({
    required this.kind,
    List<CondNode>? children,
    this.notInner,
    this.feature = 'tsh_post',
    this.op = 'gt',
    this.valueText = '',
  }) : children = children ?? [];

  factory CondNode.empty({CondKind kind = CondKind.allGroup}) {
    final n = CondNode(kind: kind);
    if (kind == CondKind.allGroup || kind == CondKind.anyGroup) {
      n.children.add(CondNode(kind: CondKind.leaf));
    } else if (kind == CondKind.notGroup) {
      n.notInner = CondNode(kind: CondKind.leaf);
    }
    return n;
  }

  factory CondNode.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('all')) {
      final n = CondNode(kind: CondKind.allGroup);
      final list = json['all'];
      if (list is List) {
        for (final c in list) {
          if (c is Map) n.children.add(CondNode.fromJson(Map<String, dynamic>.from(c)));
        }
      }
      return n;
    }
    if (json.containsKey('any')) {
      final n = CondNode(kind: CondKind.anyGroup);
      final list = json['any'];
      if (list is List) {
        for (final c in list) {
          if (c is Map) n.children.add(CondNode.fromJson(Map<String, dynamic>.from(c)));
        }
      }
      return n;
    }
    if (json.containsKey('not')) {
      final n = CondNode(kind: CondKind.notGroup);
      final inner = json['not'];
      if (inner is Map) n.notInner = CondNode.fromJson(Map<String, dynamic>.from(inner));
      return n;
    }
    final n = CondNode(kind: CondKind.leaf);
    n.feature = json['feature']?.toString() ?? 'tsh_post';
    n.op = json['op']?.toString() ?? 'eq';
    if (json.containsKey('values')) {
      final v = json['values'];
      if (v is List) n.valueText = v.map((e) => e.toString()).join(',');
    } else if (json.containsKey('value')) {
      n.valueText = json['value'].toString();
    }
    return n;
  }

  Map<String, dynamic>? toJson() {
    switch (kind) {
      case CondKind.allGroup:
      case CondKind.anyGroup:
        final list = children
            .map((c) => c.toJson())
            .whereType<Map<String, dynamic>>()
            .toList();
        if (list.isEmpty) return null;
        return {kind == CondKind.allGroup ? 'all' : 'any': list};
      case CondKind.notGroup:
        final inner = notInner?.toJson();
        if (inner == null) return null;
        return {'not': inner};
      case CondKind.leaf:
        final m = <String, dynamic>{'feature': feature, 'op': op};
        if (op == 'present' || op == 'absent') return m;
        if (op == 'in' || op == 'not_in') {
          final parts = valueText
              .split(',')
              .map((s) => _parseScalar(s.trim()))
              .where((v) => v != null)
              .toList();
          if (parts.isEmpty) return null;
          m['values'] = parts;
          return m;
        }
        if (op == 'range' || op == 'out_of_range') {
          final parts = valueText
              .split(',')
              .map((s) => _parseScalar(s.trim()))
              .whereType<num>()
              .toList();
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

class ConditionNodeEditor extends StatelessWidget {
  final CondNode node;
  final VoidCallback onChanged;

  const ConditionNodeEditor({super.key, required this.node, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, accent) = switch (node.kind) {
      CondKind.allGroup => (scheme.primaryContainer.withOpacity(0.35), scheme.primary),
      CondKind.anyGroup => (scheme.tertiaryContainer.withOpacity(0.35), scheme.tertiary),
      CondKind.notGroup => (scheme.errorContainer.withOpacity(0.30), scheme.error),
      CondKind.leaf => (scheme.surfaceContainerHigh, scheme.outlineVariant),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.45), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<CondKind>(
                value: node.kind,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: CondKind.allGroup, child: Text('ALL (и)')),
                  DropdownMenuItem(value: CondKind.anyGroup, child: Text('ANY (или)')),
                  DropdownMenuItem(value: CondKind.notGroup, child: Text('NOT')),
                  DropdownMenuItem(value: CondKind.leaf, child: Text('Условие')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  if (v == CondKind.allGroup || v == CondKind.anyGroup) {
                    if (node.kind != CondKind.allGroup && node.kind != CondKind.anyGroup) {
                      node.children = [CondNode(kind: CondKind.leaf)];
                    }
                  } else if (v == CondKind.notGroup) {
                    node.notInner ??= CondNode(kind: CondKind.leaf);
                    node.children = [];
                  } else if (v == CondKind.leaf) {
                    node.children = [];
                    node.notInner = null;
                  }
                  node.kind = v;
                  onChanged();
                },
              ),
              const Spacer(),
              if (node.kind == CondKind.allGroup || node.kind == CondKind.anyGroup)
                IconButton(
                  tooltip: 'Добавить под-условие',
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    node.children.add(CondNode(kind: CondKind.leaf));
                    onChanged();
                  },
                ),
            ],
          ),
          if (node.kind == CondKind.leaf) _LeafEditor(node: node, onChanged: onChanged),
          if (node.kind == CondKind.allGroup || node.kind == CondKind.anyGroup)
            ...List.generate(node.children.length, (i) {
              final child = node.children[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ConditionNodeEditor(node: child, onChanged: onChanged)),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
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
          if (node.kind == CondKind.notGroup && node.notInner != null)
            ConditionNodeEditor(node: node.notInner!, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LeafEditor extends StatefulWidget {
  final CondNode node;
  final VoidCallback onChanged;

  const _LeafEditor({required this.node, required this.onChanged});

  @override
  State<_LeafEditor> createState() => _LeafEditorState();
}

class _LeafEditorState extends State<_LeafEditor> {
  late final TextEditingController _valueCtrl;

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

  bool get _hasValue => widget.node.op != 'present' && widget.node.op != 'absent';
  bool get _isListValue =>
      widget.node.op == 'in' || widget.node.op == 'not_in' ||
      widget.node.op == 'range' || widget.node.op == 'out_of_range';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _features.contains(widget.node.feature) ? widget.node.feature : null,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Показатель',
                    isDense: true,
                  ),
                  items: _features
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    widget.node.feature = v;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: widget.node.op,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Оператор', isDense: true),
                  items: _ops.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      widget.node.op = v;
                    });
                    widget.onChanged();
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
                        ? 'Диапазон через запятую (0.1,0.5)'
                        : 'Значения через запятую (T1,T2,Nx)')
                    : 'Значение',
                isDense: true,
              ),
              onChanged: (v) {
                widget.node.valueText = v;
                widget.onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}
