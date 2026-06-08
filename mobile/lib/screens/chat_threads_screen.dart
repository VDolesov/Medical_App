import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ChatProvider>().loadThreads(auth);
    });
  }

  Future<void> _openNewChatPicker(BuildContext rootContext) async {
    final auth = rootContext.read<AuthProvider>();
    final chat = rootContext.read<ChatProvider>();
    if (auth.isPatient) {

      final tid = await chat.openThreadWithMyDoctor(auth);
      if (!rootContext.mounted) return;
      if (tid != null) {
        rootContext.push('/chat/$tid');
      } else {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          SnackBar(content: Text(chat.threadsError ?? 'Не удалось открыть чат')),
        );
      }
      return;
    }
    final contacts = await chat.loadContacts(auth);
    if (!rootContext.mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Нет доступных собеседников')),
      );
      return;
    }
    final picked = await showModalBottomSheet<ChatContact>(
      context: rootContext,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Выберите собеседника', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = contacts[i];
                    final isDoctor = c.role == 'DOCTOR';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDoctor ? Colors.teal.shade100 : Colors.deepPurple.shade100,
                        child: Icon(
                          isDoctor ? Icons.medical_services : Icons.admin_panel_settings,
                          color: isDoctor ? Colors.teal.shade700 : Colors.deepPurple.shade700,
                        ),
                      ),
                      title: Text(c.displayName),
                      subtitle: Text(isDoctor ? 'Врач' : 'Администратор'),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !rootContext.mounted) return;
    final tid = await chat.openThreadWith(auth, otherUserId: picked.userId);
    if (!rootContext.mounted) return;
    if (tid != null) {
      rootContext.push('/chat/$tid');
    } else {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text(chat.threadsError ?? 'Не удалось открыть чат')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootContext = context;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (_, auth, __) {

          if (auth.isPatient) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _openNewChatPicker(rootContext),
            icon: const Icon(Icons.chat),
            label: const Text('Новый чат'),
          );
        },
      ),
      body: Consumer2<ChatProvider, AuthProvider>(
        builder: (context, chat, auth, _) {
          if (chat.threadsLoading && chat.threads.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (chat.threadsError != null && chat.threads.isEmpty) {
            return _errorView(context, auth, chat.threadsError!);
          }
          if (chat.threads.isEmpty) {
            return _emptyView(context, auth);
          }
          return RefreshIndicator(
            onRefresh: () => chat.loadThreads(auth),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chat.threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = chat.threads[i];
                final title = t.otherDisplayName ?? '#${t.id}';
                final baseSub = t.subject?.isNotEmpty == true
                    ? t.subject!
                    : (t.otherRole == 'PATIENT'
                        ? 'Пациент'
                        : t.otherRole == 'DOCTOR'
                            ? 'Врач'
                            : t.otherRole == 'ADMIN'
                                ? 'Администратор'
                                : '—');
                final sub = t.blocked
                    ? '$baseSub · ${t.blockedByCurrentUser ? 'вы заблокировали чат' : 'чат заблокирован'}'
                    : baseSub;
                final when = t.lastMessageAt == null
                    ? ''
                    : '${t.lastMessageAt!.day.toString().padLeft(2, '0')}.${t.lastMessageAt!.month.toString().padLeft(2, '0')} '
                        '${t.lastMessageAt!.hour.toString().padLeft(2, '0')}:${t.lastMessageAt!.minute.toString().padLeft(2, '0')}';
                final (avatarBg, avatarIcon, avatarFg) = switch (t.otherRole) {
                  'DOCTOR' => (Colors.teal.shade100, Icons.medical_services, Colors.teal.shade700),
                  'ADMIN' => (Colors.deepPurple.shade100, Icons.admin_panel_settings, Colors.deepPurple.shade700),
                  _ => (Colors.indigo.shade100, Icons.person, Colors.indigo.shade700),
                };
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: avatarBg,
                    child: Icon(avatarIcon, color: avatarFg),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(when, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      if (t.blocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade800),
                        ),
                      if (t.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${t.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => context.push('/chat/${t.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _errorView(BuildContext context, AuthProvider auth, String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(err, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<ChatProvider>().loadThreads(auth),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView(BuildContext context, AuthProvider auth) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              auth.isPatient
                  ? 'У вас пока нет переписки с лечащим врачом.\nЧат появится, когда врач напишет вам или вы откроете его из карточки отчёта.'
                  : 'У вас пока нет чатов с пациентами.\nОткройте чат из карточки пациента в отчёте.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
