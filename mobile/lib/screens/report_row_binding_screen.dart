import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class ReportRowBindingScreen extends StatefulWidget {
  final int reportId;
  final bool isAdmin;

  const ReportRowBindingScreen({
    super.key,
    required this.reportId,
    this.isAdmin = false,
  });

  @override
  State<ReportRowBindingScreen> createState() => _ReportRowBindingScreenState();
}

class _ReportRowBindingScreenState extends State<ReportRowBindingScreen> {
  final Map<int, TextEditingController> _codeControllers = {};
  final Map<int, BindingPickerPatient?> _pickedByRow = {};
  final Map<int, bool> _manualOpen = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<ReportsProvider>();
      await Future.wait([
        p.loadReportRowsForBinding(context, widget.reportId, isAdmin: widget.isAdmin),
        p.loadBindingPickerPatients(context, isAdmin: widget.isAdmin),
      ]);
    });
  }

  @override
  void dispose() {
    for (final c in _codeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerForRow(int rowIndex) {
    return _codeControllers.putIfAbsent(rowIndex, () => TextEditingController());
  }

  String _normsSummary(PatientReport r) {
    final o = r.outOfNorms;
    if (o.isEmpty) return 'Показатели: нет данных';
    final maps = o.whereType<Map>().toList();
    if (maps.isEmpty) {
      final flat = o.map((e) => e.toString()).join(' ');
      if (flat.contains('норме')) return 'Все показатели в норме';
      return 'Данные анализов: ${o.length} зн.';
    }
    return 'Отклонений от нормы: ${maps.length}';
  }

  List<Map> _normMaps(PatientReport r) => r.outOfNorms.whereType<Map>().toList();

  Future<void> _confirmAttach({
    required BuildContext context,
    required ReportsProvider provider,
    required int rowIndex,
    required PatientReport row,
    required String patientCode,
    required TextEditingController ctrl,
    BindingPickerPatient? picked,
  }) async {
    final excelPos = rowIndex + 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите привязку'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Отчёт №${widget.reportId}, строка данных №$excelPos (внутренний индекс: $rowIndex).',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('В файле сейчас: код «${row.code.isEmpty ? '—' : row.code}», возраст ${row.age}'),
              const SizedBox(height: 8),
              Text(_normsSummary(row)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Будет привязан пациент: $patientCode', style: const TextStyle(color: Colors.green)),
              if (picked != null && picked.lkUserName != null && picked.lkUserName!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Пользователь ЛК: ${picked.lkUserName!.trim()}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Убедитесь, что код соответствует нужному человеку. После привязки изменить пациента можно, отвязав строку.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Привязать')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final err = await provider.attachPatientToRow(
      context,
      reportId: widget.reportId,
      rowIndex: rowIndex,
      patientCode: patientCode,
      isAdmin: widget.isAdmin,
    );
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ctrl.clear();
      setState(() => _pickedByRow.remove(rowIndex));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Привязка сохранена')),
      );
    }
  }

  Future<void> _openPickerSheet(int rowIndex) async {
    final picked = await showModalBottomSheet<BindingPickerPatient?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PatientPickerSheet(isAdmin: widget.isAdmin),
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedByRow[rowIndex] = picked;
        _controllerForRow(rowIndex).text = picked.code;
      });
    }
  }

  Future<void> _confirmDetach(
    BuildContext context,
    ReportsProvider provider,
    int rowIndex,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отвязать строку?'),
        content: Text(
          'Строка №${rowIndex + 1} перестанет быть связана с пациентом ЛК. Продолжить?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await provider.detachPatientFromRow(
      context,
      reportId: widget.reportId,
      rowIndex: rowIndex,
      isAdmin: widget.isAdmin,
    );
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => _pickedByRow.remove(rowIndex));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отвязано')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!widget.isAdmin && !auth.isDoctor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Привязка строк')),
        body: const Center(child: Text('Доступно только врачу')),
      );
    }
    if (widget.isAdmin && !auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Привязка строк')),
        body: const Center(child: Text('Доступно только администратору')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Привязка строк к пациентам'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить отчёт и список пациентов',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final p = context.read<ReportsProvider>();
              await Future.wait([
                p.loadReportRowsForBinding(context, widget.reportId, isAdmin: widget.isAdmin),
                p.loadBindingPickerPatients(context, isAdmin: widget.isAdmin),
              ]);
            },
          ),
        ],
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, _) {
          if (provider.bindingLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.bindingError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(provider.bindingError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadReportRowsForBinding(
                        context,
                        widget.reportId,
                        isAdmin: widget.isAdmin,
                      ),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          final rows = provider.bindingRows;
          final total = provider.bindingReportTotal ?? rows.length;

          if (rows.isEmpty) {
            return const Center(child: Text('Нет строк в отчёте'));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Отчёт №${widget.reportId}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Всего строк данных: $total. Каждая строка — отдельная запись из Excel; номер «№» — порядок в файле (первая строка = 1).',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                      if (provider.bindingPickerLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        )
                      else if (provider.bindingPickerError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            provider.bindingPickerError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                          ),
                        )
                      else if (!widget.isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'В списке для привязки — только пациенты с учётной записью в приложении (ЛК), с которыми вы можете работать по правилам закрепления (свободные или ваши).',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      provider.loadReportRowsForBinding(context, widget.reportId, isAdmin: widget.isAdmin),
                      provider.loadBindingPickerPatients(context, isAdmin: widget.isAdmin),
                    ]);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      final rowIndex = r.rowIndex ?? index;
                      final ctrl = _controllerForRow(rowIndex);
                      final linked = r.linkStatus == 'linked';
                      final broken = r.linkStatus == 'broken';
                      final excelPos = rowIndex + 1;
                      final picked = _pickedByRow[rowIndex];
                      final normMaps = _normMaps(r);
                      final manual = _manualOpen[rowIndex] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    child: Text('$excelPos'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Строка №$excelPos',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'Индекс для API: $rowIndex',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (linked)
                                    Chip(
                                      label: const Text('Привязано'),
                                      backgroundColor: Colors.green.shade100,
                                      visualDensity: VisualDensity.compact,
                                    )
                                  else if (broken)
                                    Chip(
                                      label: const Text('Связь устарела'),
                                      backgroundColor: Colors.orange.shade100,
                                      visualDensity: VisualDensity.compact,
                                    )
                                  else
                                    Chip(
                                      label: const Text('Не привязано'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _InfoChip(icon: Icons.tag, label: 'Код в файле: ${r.code.isEmpty ? '—' : r.code}'),
                                  _InfoChip(icon: Icons.cake_outlined, label: 'Возраст: ${r.age}'),
                                  _InfoChip(icon: Icons.monitor_heart_outlined, label: _normsSummary(r)),
                                ],
                              ),
                              if (normMaps.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      'Подробнее по отклонениям (${normMaps.length})',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                    ),
                                    children: [
                                      for (final m in normMaps.take(6))
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '${m['analysis'] ?? 'Анализ'}: ${m['value']} ${m['unit'] ?? ''} '
                                              '(норма ${m['min']}–${m['max']}, ${m['status'] ?? ''})',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      if (normMaps.length > 6)
                                        Text(
                                          '… и ещё ${normMaps.length - 6}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (linked && r.linkCode != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Связано с пациентом ЛК: ${r.linkCode}',
                                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w500),
                                ),
                              ],
                              if (broken) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Ранее выбранный пациент не найден в базе — привяжите снова.',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ],
                              if (r.attendingDoctorLabel != null && r.attendingDoctorLabel!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Ведущий врач по ЛК: ${r.attendingDoctorLabel}',
                                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                                ),
                              ],
                              if (r.linkLockedForMe && !widget.isAdmin) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Эта строка закреплена за другим врачом — снять привязку может только администратор.',
                                  style: TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (r.canAttach) ...[
                                if (picked != null)
                                  InputChip(
                                    avatar: const Icon(Icons.person_search, size: 18),
                                    label: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          picked.code,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          picked.choiceSubtitle,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _pickedByRow.remove(rowIndex);
                                        ctrl.clear();
                                      });
                                    },
                                  ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: provider.bindingPickerLoading
                                      ? null
                                      : () => _openPickerSheet(rowIndex),
                                  icon: const Icon(Icons.list_alt),
                                  label: Text(widget.isAdmin
                                      ? 'Выбрать пациента из списка'
                                      : 'Выбрать из списка (ЛК)'),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => setState(() => _manualOpen[rowIndex] = !manual),
                                  child: Row(
                                    children: [
                                      Icon(manual ? Icons.expand_less : Icons.expand_more, size: 20),
                                      Text(
                                        manual ? 'Скрыть ручной ввод кода' : 'Или ввести код вручную (P-…)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (manual) ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Код пациента',
                                      hintText: 'Например P-12345',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    autocorrect: false,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: () {
                                    final code = (picked?.code ?? ctrl.text).trim();
                                    if (code.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Выберите пациента из списка или введите код'),
                                        ),
                                      );
                                      return;
                                    }
                                    _confirmAttach(
                                      context: context,
                                      provider: provider,
                                      rowIndex: rowIndex,
                                      row: r,
                                      patientCode: code,
                                      ctrl: ctrl,
                                      picked: picked,
                                    );
                                  },
                                  icon: const Icon(Icons.link),
                                  label: const Text('Привязать к выбранному пациенту'),
                                ),
                              ],
                              if (r.canDetach)
                                TextButton.icon(
                                  onPressed: () => _confirmDetach(context, provider, rowIndex),
                                  icon: const Icon(Icons.link_off),
                                  label: const Text('Отвязать строку'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _PatientPickerSheet extends StatefulWidget {
  final bool isAdmin;

  const _PatientPickerSheet({required this.isAdmin});

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsProvider>().loadBindingPickerPatients(
            context,
            isAdmin: widget.isAdmin,
          );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      context.read<ReportsProvider>().loadBindingPickerPatients(
            context,
            isAdmin: widget.isAdmin,
            query: q,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.isAdmin ? 'Выбор пациента' : 'Зарегистрированные в ЛК',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Поиск по коду пациента',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<ReportsProvider>(
                builder: (context, provider, _) {
                  if (provider.bindingPickerLoading && provider.bindingPickerPatients.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = provider.bindingPickerPatients;
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          provider.bindingPickerError ??
                              _emptyHint(widget.isAdmin),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return ListTile(
                        leading: Icon(
                          p.hasAppAccount ? Icons.badge_outlined : Icons.person_outline,
                          color: p.hasAppAccount ? Colors.teal : null,
                        ),
                        title: Text(p.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                        isThreeLine: true,
                        subtitle: Text(
                          p.listTileSubtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.25),
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyHint(bool isAdmin) {
    if (isAdmin) {
      return 'Нет пациентов по запросу. Измените поиск или убедитесь, что у пациента есть учётная запись в ЛК.';
    }
    return 'Нет зарегистрированных в ЛК среди доступных вам по закреплению. Попробуйте поиск или введите код P-… вручную на экране привязки.';
  }
}
