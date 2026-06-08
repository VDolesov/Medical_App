import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _adminSecret = TextEditingController();
  final _age = TextEditingController(text: '30');

  String _role = 'patient';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _adminSecret.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final patientCode = await auth.register(
      username: _username.text.trim(),
      password: _password.text,
      email: _email.text.trim(),
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      role: _role,
      adminSecret: _role == 'patient' ? null : _adminSecret.text.trim(),
      patientAge: _role == 'patient' ? int.tryParse(_age.text.trim()) : null,
    );
    if (!mounted) return;
    if (auth.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.lastError!)));
      return;
    }
    if (_role == 'patient' && patientCode != null) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Аккаунт создан'),
          content: Text('Код пациента: $patientCode\n\nПередайте этот код врачу — он понадобится для связи отчётов.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Аккаунт создан, можно войти')));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'patient', label: Text('Пациент'), icon: Icon(Icons.person)),
                    ButtonSegment(value: 'doctor', label: Text('Врач'), icon: Icon(Icons.medical_services)),
                    ButtonSegment(value: 'admin', label: Text('Админ'), icon: Icon(Icons.shield)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 16),
                TextField(controller: _username, decoration: const InputDecoration(labelText: 'Логин')),
                const SizedBox(height: 10),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Пароль'), obscureText: true),
                const SizedBox(height: 10),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'Имя'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Фамилия'))),
                  ],
                ),
                if (_role == 'patient') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _age,
                    decoration: const InputDecoration(labelText: 'Возраст'),
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _adminSecret,
                    decoration: const InputDecoration(labelText: 'Секретный код'),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Создать аккаунт'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
