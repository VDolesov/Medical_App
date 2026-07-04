import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  String? _error;
  String _filter = 'all';

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
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/users'), headers: _headers());
      if (r.statusCode == 200) {
        final body = json.decode(utf8.decode(r.bodyBytes));
        if (body is List) {
          _users = body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<void> _delete(Map<String, dynamic> user) async {
    final id = (user['id'] as num).toInt();
    final myId = context.read<AuthProvider>().user?.id;
    if (id == myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить себя самого')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('${user['username']} (${user['role']})\n\nЭто действие нельзя отменить.'),
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
    final r = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/admin/users/$id'),
      headers: _headers(),
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователь удалён')));
    } else {
      _toastError(r);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? user}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _UserEditor(user: user),
        fullscreenDialog: true,
      ),
    );
    if (changed == true) await _load();
  }

  void _toastError(http.Response r) {
    String msg = 'HTTP ${r.statusCode}';
    try {
      final m = json.decode(utf8.decode(r.bodyBytes));
      if (m is Map && m['error'] != null) msg = m['error'].toString();
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _users
        : _users.where((u) => (u['role']?.toString() ?? '').toLowerCase() == _filter).toList();
    final byRole = <String, int>{};
    for (final u in _users) {
      final r = (u['role']?.toString() ?? '').toLowerCase();
      byRole[r] = (byRole[r] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Новый'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('Все · ${_users.length}'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                ),
                _roleChip('doctor', 'Врачи', byRole['doctor'] ?? 0),
                _roleChip('admin', 'Админы', byRole['admin'] ?? 0),
                _roleChip('patient', 'Пациенты', byRole['patient'] ?? 0),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(filtered)),
        ],
      ),
    );
  }

  Widget _roleChip(String role, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('$label · $count'),
        selected: _filter == role,
        onSelected: (_) => setState(() => _filter = _filter == role ? 'all' : role),
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> filtered) {
    if (_loading && _users.isEmpty) return const LoadingIndicator();
    if (_error != null && _users.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: _error,
        actionLabel: 'Повторить',
        onAction: _load,
      );
    }
    if (filtered.isEmpty) {
      return const EmptyState(icon: Icons.group_outlined, title: 'Никого не найдено');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _UserTile(
          user: filtered[i],
          onEdit: () => _openEditor(user: filtered[i]),
          onDelete: () => _delete(filtered[i]),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserTile({required this.user, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = (user['role']?.toString() ?? '').toLowerCase();
    final fn = user['first_name']?.toString() ?? '';
    final ln = user['last_name']?.toString() ?? '';
    final username = user['username']?.toString() ?? '?';
    final fullName = ('$ln $fn').trim();
    final (bg, fg, icon, roleLabel) = switch (role) {
      'doctor' => (Colors.teal.shade100, Colors.teal.shade700, Icons.medical_services, 'Врач'),
      'admin' => (Colors.deepPurple.shade100, Colors.deepPurple.shade700, Icons.admin_panel_settings, 'Администратор'),
      'patient' => (Colors.indigo.shade100, Colors.indigo.shade700, Icons.person, 'Пациент'),
      _ => (scheme.surfaceContainerHigh, scheme.onSurfaceVariant, Icons.help_outline, role),
    };
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: bg, foregroundColor: fg, child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? username : fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username  ·  $roleLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if ((user['email'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(user['email'].toString(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Редактировать')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserEditor extends StatefulWidget {
  final Map<String, dynamic>? user;
  const _UserEditor({this.user});

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  String _role = 'doctor';
  bool _saving = false;
  String? _err;

  bool get _isCreate => widget.user == null;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _username.text = widget.user!['username']?.toString() ?? '';
      _email.text = widget.user!['email']?.toString() ?? '';
      _firstName.text = widget.user!['first_name']?.toString() ?? '';
      _lastName.text = widget.user!['last_name']?.toString() ?? '';
      _role = (widget.user!['role']?.toString() ?? 'doctor').toLowerCase();
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Map<String, String> _headers() {
    final t = context.read<AuthProvider>().token;
    return {
      if (t != null) 'Authorization': 'Bearer $t',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  Future<void> _save() async {
    setState(() {
      _err = null;
      _saving = true;
    });
    try {
      if (_isCreate) {
        if (_username.text.trim().isEmpty) throw 'Логин обязателен';
        if (_password.text.isEmpty) throw 'Пароль обязателен';
        if (_email.text.trim().isEmpty) throw 'Email обязателен';
        if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) throw 'Имя и фамилия обязательны';
        if (_role != 'doctor' && _role != 'admin') {
          throw 'Через админку создаются только врачи и админы. Пациент регистрируется через форму регистрации.';
        }
        final r = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/admin/users'),
          headers: _headers(),
          body: json.encode({
            'username': _username.text.trim(),
            'password': _password.text,
            'email': _email.text.trim(),
            'firstName': _firstName.text.trim(),
            'lastName': _lastName.text.trim(),
            'role': _role,
          }),
        );
        if (r.statusCode != 200) throw _readError(r);
      } else {
        final id = (widget.user!['id'] as num).toInt();
        final body = <String, dynamic>{
          if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
          if (_firstName.text.trim().isNotEmpty) 'firstName': _firstName.text.trim(),
          if (_lastName.text.trim().isNotEmpty) 'lastName': _lastName.text.trim(),
          'role': _role,
          if (_password.text.isNotEmpty) 'password': _password.text,
        };
        final r = await http.patch(
          Uri.parse('${ApiConfig.baseUrl}/admin/users/$id'),
          headers: _headers(),
          body: json.encode(body),
        );
        if (r.statusCode != 200) throw _readError(r);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isCreate ? 'Пользователь создан' : 'Пользователь обновлён')),
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
        title: Text(_isCreate ? 'Новый пользователь' : 'Редактирование пользователя'),
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
              decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_err!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'doctor', label: Text('Врач'), icon: Icon(Icons.medical_services)),
              ButtonSegment(value: 'admin', label: Text('Админ'), icon: Icon(Icons.admin_panel_settings)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            enabled: _isCreate,
            decoration: const InputDecoration(labelText: 'Логин', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _isCreate ? 'Пароль' : 'Новый пароль (не обязательно)',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'Имя'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Фамилия'))),
            ],
          ),
        ],
      ),
    );
  }
}
