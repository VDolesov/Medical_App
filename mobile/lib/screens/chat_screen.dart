import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final int threadId;
  final int? initialLinkedReportId;
  final int? initialLinkedRuleExecutionId;
  final String? initialPrefill;

  const ChatScreen({
    super.key,
    required this.threadId,
    this.initialLinkedReportId,
    this.initialLinkedRuleExecutionId,
    this.initialPrefill,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _blocking = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrefill != null && widget.initialPrefill!.isNotEmpty) {
      _controller.text = widget.initialPrefill!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();
      if (chat.threadById(widget.threadId) == null) {
        await chat.loadThreads(auth);
      }
      await chat.loadMessages(auth, widget.threadId);
      await chat.markRead(auth, widget.threadId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    final ok = await chat.sendMessage(
      auth,
      widget.threadId,
      text,
      linkedReportId: widget.initialLinkedReportId,
      linkedRuleExecutionId: widget.initialLinkedRuleExecutionId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      _scrollToBottom();
      return;
    }
    final err = chat.messagesError(widget.threadId) ?? 'Не удалось отправить сообщение';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  Future<void> _confirmBlock(ChatThread thread) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заблокировать чат?'),
        content: const Text(
          'После блокировки врач и пациент не смогут отправлять новые сообщения в этой переписке, '
          'пока вы не разблокируете чат. История сообщений сохранится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _setBlocked(thread, true);
    }
  }

  Future<void> _setBlocked(ChatThread thread, bool blocked) async {
    if (_blocking) return;
    setState(() => _blocking = true);
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    final ok = blocked
        ? await chat.blockThread(auth, thread.id)
        : await chat.unblockThread(auth, thread.id);
    if (!mounted) return;
    setState(() => _blocking = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.threadsError ?? 'Не удалось изменить блокировку чата')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, AuthProvider>(
      builder: (context, chat, auth, _) {
        final thread = chat.threadById(widget.threadId);
        return Scaffold(
          appBar: AppBar(
            title: Text(thread?.otherDisplayName ?? 'Чат'),
            actions: [
              if (thread != null && !thread.closed)
                IconButton(
                  tooltip: thread.blockedByCurrentUser ? 'Разблокировать чат' : 'Заблокировать чат',
                  onPressed: _blocking
                      ? null
                      : () => thread.blockedByCurrentUser
                          ? _setBlocked(thread, false)
                          : _confirmBlock(thread),
                  icon: Icon(thread.blockedByCurrentUser ? Icons.lock_open : Icons.block),
                ),
            ],
          ),
          body: Column(
            children: [
              if (thread != null && thread.blocked) _blockNotice(thread),
              Expanded(child: _messagesList()),
              _composer(thread),
            ],
          ),
        );
      },
    );
  }

  Widget _messagesList() {
    return Consumer2<ChatProvider, AuthProvider>(
      builder: (context, chat, auth, _) {
        final loading = chat.messagesLoading(widget.threadId);
        final err = chat.messagesError(widget.threadId);
        final msgs = chat.messagesFor(widget.threadId);
        if (loading && msgs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (err != null && msgs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(err, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        if (msgs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Сообщений пока нет. Напишите первое сообщение — собеседник увидит уведомление в приложении.',
                style: TextStyle(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final myUserId = auth.user?.id;
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: msgs.length,
          itemBuilder: (context, i) {
            final m = msgs[i];
            final mine = m.senderUserId == myUserId;
            return _bubble(m, mine);
          },
        );
      },
    );
  }

  Widget _bubble(ChatMessage m, bool mine) {
    final bg = mine ? Colors.blue.shade600 : Colors.grey.shade200;
    final fg = mine ? Colors.white : Colors.black87;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final when = m.createdAt;
    final ts = when == null
        ? ''
        : '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!mine && (m.senderDisplayName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                m.senderDisplayName!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 2),
                bottomRight: Radius.circular(mine ? 2 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: align,
              children: [
                if (m.linkedRuleExecutionId != null || m.linkedReportId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _linkBanner(m, mine),
                  ),
                Text(m.body, style: TextStyle(color: fg, height: 1.35)),
                const SizedBox(height: 2),
                Text(
                  ts,
                  style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkBanner(ChatMessage m, bool mine) {
    final fg = mine ? Colors.white : Colors.indigo.shade800;
    final bg = mine ? Colors.white24 : Colors.indigo.shade50;
    final label = m.linkedRuleExecutionId != null
        ? 'Привязка к правилу #${m.linkedRuleExecutionId}'
        : 'Привязка к отчёту #${m.linkedReportId}';
    final icon = m.linkedRuleExecutionId != null
        ? Icons.psychology_alt
        : Icons.description_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(color: fg, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _blockNotice(ChatThread thread) {
    String text;
    if (thread.blockedByCurrentUser && thread.blockedByOtherUser) {
      text = 'Переписка заблокирована обеими сторонами. Новые сообщения недоступны.';
    } else if (thread.blockedByCurrentUser) {
      text = 'Вы заблокировали эту переписку. Новые сообщения недоступны, пока вы не разблокируете чат.';
    } else {
      text = 'Собеседник временно заблокировал эту переписку. Новые сообщения сейчас недоступны.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.amber.shade900, height: 1.3),
            ),
          ),
          if (thread.blockedByCurrentUser)
            TextButton(
              onPressed: _blocking ? null : () => _setBlocked(thread, false),
              child: const Text('Разблокировать'),
            ),
        ],
      ),
    );
  }

  Widget _composer(ChatThread? thread) {
    final disabledReason = _disabledComposerReason(thread);
    final disabled = disabledReason != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !disabled && !_sending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: disabledReason ?? 'Сообщение...',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: disabled || _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  String? _disabledComposerReason(ChatThread? thread) {
    if (thread == null) return null;
    if (thread.closed) return 'Чат закрыт';
    if (!thread.blocked) return null;
    if (thread.blockedByCurrentUser) {
      return 'Вы заблокировали чат';
    }
    return 'Чат заблокирован собеседником';
  }
}
