import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadThreads();
    });
  }

  Future<void> _newChat() async {
    final rootContext = context;
    final auth = rootContext.read<AuthProvider>();
    final chat = rootContext.read<ChatProvider>();
    if (auth.isPatient) {
      final tid = await chat.openWithMyDoctor();
      if (rootContext.mounted && tid != null) rootContext.push('/chats/$tid');
      return;
    }
    final contacts = await chat.loadContacts();
    if (!rootContext.mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Нет доступных собеседников')),
      );
      return;
    }
    final picked = await showModalBottomSheet<ChatContact>(
      context: rootContext,
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
              const SizedBox(height: 12),
              Text('Кому написать?', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
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
                        backgroundColor: isDoctor
                            ? Colors.teal.shade100
                            : Colors.deepPurple.shade100,
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
    final tid = await chat.openWith(otherUserId: picked.userId);
    if (!rootContext.mounted) return;
    if (tid != null) {
      rootContext.push('/chats/$tid');
    } else {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text(chat.threadsError ?? 'Не удалось открыть чат')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Чаты')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.edit_note),
        label: const Text('Новый чат'),
      ),
      body: RefreshIndicator(
        onRefresh: () => chat.loadThreads(),
        child: _body(context, chat, auth),
      ),
    );
  }

  Widget _body(BuildContext context, ChatProvider chat, AuthProvider auth) {
    if (chat.loadingThreads && chat.threads.isEmpty) {
      return const LoadingIndicator();
    }
    if (chat.threadsError != null && chat.threads.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить',
        subtitle: chat.threadsError,
        actionLabel: 'Повторить',
        onAction: () => chat.loadThreads(),
      );
    }
    if (chat.threads.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'Чатов пока нет',
        subtitle: auth.isPatient
            ? 'Нажмите «Новый чат», чтобы написать лечащему врачу.'
            : 'Нажмите «Новый чат», чтобы начать переписку.',
        actionLabel: 'Новый чат',
        onAction: _newChat,
      );
    }
    final fmt = DateFormat('dd MMM HH:mm', 'ru');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      itemCount: chat.threads.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (_, i) {
        final t = chat.threads[i];
        final (bg, fg, icon, roleLabel) = switch (t.otherRole) {
          'DOCTOR' => (Colors.teal.shade100, Colors.teal.shade700, Icons.medical_services, 'Врач'),
          'ADMIN' => (Colors.deepPurple.shade100, Colors.deepPurple.shade700, Icons.admin_panel_settings, 'Администратор'),
          _ => (Colors.indigo.shade100, Colors.indigo.shade700, Icons.person, 'Пациент'),
        };
        final hasUnread = t.unreadCount > 0;
        final scheme = Theme.of(context).colorScheme;
        return ListTile(
          onTap: () => context.push('/chats/${t.id}'),
          leading: CircleAvatar(backgroundColor: bg, foregroundColor: fg, child: Icon(icon)),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  t.otherDisplayName ?? '#${t.id}',
                  style: TextStyle(fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (t.blocked) ...[
                const SizedBox(width: 6),
                Icon(Icons.block_outlined, size: 16, color: scheme.error),
              ],
            ],
          ),
          subtitle: Text(
            t.blocked
                ? (t.blockedByCurrentUser ? 'Вы заблокировали чат' : 'Собеседник заблокировал чат')
                : (t.subject?.isNotEmpty == true ? t.subject! : roleLabel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.blocked ? TextStyle(color: scheme.error) : null,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.lastMessageAt == null ? '' : fmt.format(t.lastMessageAt!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
              if (hasUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Badge(label: Text('${t.unreadCount}')),
                ),
            ],
          ),
        );
      },
    );
  }
}
