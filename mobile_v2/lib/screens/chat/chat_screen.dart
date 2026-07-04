import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final int threadId;
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatProvider>();
      if (chat.threadById(widget.threadId) == null) {
        await chat.loadThreads();
      }
      await chat.loadMessages(widget.threadId);
      await chat.markRead(widget.threadId);
      _toBottom();
    });
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final chat = context.read<ChatProvider>();
    setState(() => _sending = true);
    final ok = await chat.sendMessage(widget.threadId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _ctrl.clear();
      _toBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.lastSendError ?? 'Не удалось отправить')),
      );
    }
  }

  Future<void> _toggleBlock(ChatThread thread) async {
    final scaffold = ScaffoldMessenger.of(context);
    final chat = context.read<ChatProvider>();
    final blocked = thread.blockedByCurrentUser;
    if (!blocked) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Заблокировать чат?'),
          content: const Text(
              'Собеседник не сможет отправлять сообщения, а вы — отвечать в этом диалоге. Снять блокировку можно в любой момент.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Заблокировать')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    final updated = await chat.setBlocked(thread.id, !blocked);
    if (!mounted) return;
    if (updated == null) {
      scaffold.showSnackBar(const SnackBar(content: Text('Не удалось изменить статус блокировки')));
      return;
    }
    scaffold.showSnackBar(SnackBar(
      content: Text(updated.blockedByCurrentUser ? 'Чат заблокирован' : 'Блокировка снята'),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = context.watch<AuthProvider>().user?.id;
    final chat = context.watch<ChatProvider>();
    final thread = chat.threadById(widget.threadId);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(thread?.otherDisplayName ?? 'Чат',
                style: Theme.of(context).textTheme.titleMedium),
            if (thread?.otherRole != null)
              Text(
                _roleLabel(thread!.otherRole!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          if (thread != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Действия',
              onSelected: (v) {
                if (v == 'block' || v == 'unblock') {
                  _toggleBlock(thread);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: thread.blockedByCurrentUser ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(
                        thread.blockedByCurrentUser ? Icons.lock_open_outlined : Icons.block_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(thread.blockedByCurrentUser ? 'Разблокировать чат' : 'Заблокировать чат'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (thread != null && thread.blocked) _blockedBanner(thread),
            Expanded(child: _messagesView(chat, myUserId)),
            _composer(blockedThread: thread),
          ],
        ),
      ),
    );
  }

  Widget _blockedBanner(ChatThread thread) {
    final scheme = Theme.of(context).colorScheme;
    final byMe = thread.blockedByCurrentUser;
    final byOther = thread.blockedByOtherUser;
    final title = byMe && byOther
        ? 'Чат заблокирован с обеих сторон'
        : byMe
            ? 'Вы заблокировали этот чат'
            : 'Собеседник заблокировал чат';
    final subtitle = byMe
        ? 'Отправка сообщений недоступна, пока вы не снимете блокировку.'
        : 'Сообщения нельзя отправлять, пока собеседник не снимет блокировку.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.block_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
              ],
            ),
          ),
          if (byMe)
            TextButton(
              onPressed: () => _toggleBlock(thread),
              style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
              child: const Text('Снять'),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String r) => switch (r) {
        'DOCTOR' => 'Врач',
        'PATIENT' => 'Пациент',
        'ADMIN' => 'Администратор',
        _ => r,
      };

  Widget _messagesView(ChatProvider chat, int? myUserId) {
    final loading = chat.messagesLoading(widget.threadId);
    final msgs = chat.messages(widget.threadId);
    if (loading && msgs.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Сообщений пока нет.\nНапишите первое.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ),
      );
    }
    final timeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('d MMMM', 'ru');
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      itemCount: msgs.length,
      itemBuilder: (_, i) {
        final m = msgs[i];
        final mine = m.senderUserId == myUserId;
        final prev = i > 0 ? msgs[i - 1] : null;
        final showDay = prev == null ||
            (m.createdAt != null && prev.createdAt != null && _diffDay(m.createdAt!, prev.createdAt!));
        return Column(
          children: [
            if (showDay && m.createdAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(dayFmt.format(m.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            _bubble(m, mine, timeFmt),
          ],
        );
      },
    );
  }

  bool _diffDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  Widget _bubble(ChatMessage m, bool mine, DateFormat timeFmt) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine && (m.senderDisplayName ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(m.senderDisplayName!,
                    style: TextStyle(color: fg.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            if (m.linkedRuleExecutionId != null || m.linkedReportId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fg.withOpacity(mine ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      m.linkedRuleExecutionId != null ? Icons.psychology_alt_outlined : Icons.description_outlined,
                      size: 14,
                      color: fg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      m.linkedRuleExecutionId != null
                          ? 'Привязка к правилу #${m.linkedRuleExecutionId}'
                          : 'Отчёт #${m.linkedReportId}',
                      style: TextStyle(color: fg, fontSize: 11),
                    ),
                  ],
                ),
              ),
            Text(m.body, style: TextStyle(color: fg, height: 1.35)),
            if (m.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(timeFmt.format(m.createdAt!),
                    style: TextStyle(color: fg.withOpacity(0.7), fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer({ChatThread? blockedThread}) {
    final scheme = Theme.of(context).colorScheme;
    final isBlocked = blockedThread != null && blockedThread.blocked;
    final isClosed = blockedThread != null && blockedThread.closed;
    final disabled = isBlocked || isClosed;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              enabled: !disabled,
              decoration: InputDecoration(
                hintText: isBlocked
                    ? (blockedThread!.blockedByCurrentUser
                        ? 'Снимите блокировку, чтобы написать'
                        : 'Собеседник заблокировал чат')
                    : isClosed
                        ? 'Чат закрыт'
                        : 'Сообщение…',
              ),
              onSubmitted: disabled ? null : (_) => _send(),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: (_sending || disabled) ? null : _send,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(disabled ? Icons.block_outlined : Icons.send),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
