import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class ChatThread {
  final int id;
  final int patientUserId;
  final int doctorUserId;
  final String? otherDisplayName;
  final String? otherRole;
  final String? subject;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool closed;
  final bool blocked;
  final bool blockedByCurrentUser;
  final bool blockedByOtherUser;
  final String? blockedByRole;
  final DateTime? blockedAt;

  ChatThread({
    required this.id,
    required this.patientUserId,
    required this.doctorUserId,
    this.otherDisplayName,
    this.otherRole,
    this.subject,
    this.lastMessageAt,
    required this.unreadCount,
    required this.closed,
    this.blocked = false,
    this.blockedByCurrentUser = false,
    this.blockedByOtherUser = false,
    this.blockedByRole,
    this.blockedAt,
  });

  ChatThread copyWith({
    int? unreadCount,
    bool? blocked,
    bool? blockedByCurrentUser,
    bool? blockedByOtherUser,
    String? blockedByRole,
    DateTime? blockedAt,
  }) {
    return ChatThread(
      id: id,
      patientUserId: patientUserId,
      doctorUserId: doctorUserId,
      otherDisplayName: otherDisplayName,
      otherRole: otherRole,
      subject: subject,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      closed: closed,
      blocked: blocked ?? this.blocked,
      blockedByCurrentUser: blockedByCurrentUser ?? this.blockedByCurrentUser,
      blockedByOtherUser: blockedByOtherUser ?? this.blockedByOtherUser,
      blockedByRole: blockedByRole ?? this.blockedByRole,
      blockedAt: blockedAt ?? this.blockedAt,
    );
  }

  factory ChatThread.fromJson(Map<String, dynamic> j) {
    DateTime? ts;
    final raw = j['lastMessageAt'];
    if (raw is String && raw.isNotEmpty) ts = DateTime.tryParse(raw);
    DateTime? blockedTs;
    final rawBlocked = j['blockedAt'];
    if (rawBlocked is String && rawBlocked.isNotEmpty) blockedTs = DateTime.tryParse(rawBlocked);
    return ChatThread(
      id: (j['id'] as num).toInt(),
      patientUserId: (j['patientUserId'] as num?)?.toInt() ?? 0,
      doctorUserId: (j['doctorUserId'] as num?)?.toInt() ?? 0,
      otherDisplayName: j['otherDisplayName']?.toString(),
      otherRole: j['otherRole']?.toString(),
      subject: j['subject']?.toString(),
      lastMessageAt: ts,
      unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
      closed: j['closed'] == true,
      blocked: j['blocked'] == true,
      blockedByCurrentUser: j['blockedByCurrentUser'] == true,
      blockedByOtherUser: j['blockedByOtherUser'] == true,
      blockedByRole: j['blockedByRole']?.toString(),
      blockedAt: blockedTs,
    );
  }
}

class ChatMessage {
  final int id;
  final int senderUserId;
  final String? senderDisplayName;
  final String body;
  final DateTime? createdAt;
  final bool readByRecipient;
  final int? linkedReportId;
  final int? linkedRuleExecutionId;

  ChatMessage({
    required this.id,
    required this.senderUserId,
    this.senderDisplayName,
    required this.body,
    this.createdAt,
    required this.readByRecipient,
    this.linkedReportId,
    this.linkedRuleExecutionId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    DateTime? ts;
    final raw = j['createdAt'];
    if (raw is String && raw.isNotEmpty) ts = DateTime.tryParse(raw);
    return ChatMessage(
      id: (j['id'] as num).toInt(),
      senderUserId: (j['senderUserId'] as num?)?.toInt() ?? 0,
      senderDisplayName: j['senderDisplayName']?.toString(),
      body: j['body']?.toString() ?? '',
      createdAt: ts,
      readByRecipient: j['readByRecipient'] == true,
      linkedReportId: (j['linkedReportId'] as num?)?.toInt(),
      linkedRuleExecutionId: (j['linkedRuleExecutionId'] as num?)?.toInt(),
    );
  }
}

class ChatContact {
  final int userId;
  final String displayName;
  final String role;
  ChatContact({required this.userId, required this.displayName, required this.role});
  factory ChatContact.fromJson(Map<String, dynamic> j) => ChatContact(
        userId: (j['userId'] as num).toInt(),
        displayName: j['displayName']?.toString() ?? '?',
        role: j['role']?.toString() ?? '',
      );
}

class ChatProvider with ChangeNotifier {
  final ApiClient _api;
  ChatProvider(this._api);

  List<ChatThread> _threads = [];
  bool _loadingThreads = false;
  String? _threadsError;
  int _unreadTotal = 0;
  String? _lastSendError;

  final Map<int, List<ChatMessage>> _msgs = {};
  final Map<int, bool> _msgsLoading = {};

  List<ChatThread> get threads => List.unmodifiable(_threads);
  bool get loadingThreads => _loadingThreads;
  String? get threadsError => _threadsError;
  int get unreadTotal => _unreadTotal;
  String? get lastSendError => _lastSendError;
  List<ChatMessage> messages(int threadId) => List.unmodifiable(_msgs[threadId] ?? const []);
  bool messagesLoading(int threadId) => _msgsLoading[threadId] == true;

  ChatThread? threadById(int id) {
    for (final t in _threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> loadThreads() async {
    _loadingThreads = true;
    _threadsError = null;
    notifyListeners();
    final r = await _api.get('/chat/threads');
    if (r.ok) {
      _threads = r.asList().whereType<Map>().map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e))).toList();
      _unreadTotal = _threads.fold(0, (s, t) => s + t.unreadCount);
    } else {
      _threadsError = r.errorMessage;
    }
    _loadingThreads = false;
    notifyListeners();
  }

  Future<int> refreshUnread() async {
    final r = await _api.get('/chat/unread-count');
    if (r.ok && r.body is Map) {
      _unreadTotal = (r.asMap()['unread'] as num?)?.toInt() ?? _unreadTotal;
      notifyListeners();
    }
    return _unreadTotal;
  }

  Future<List<ChatContact>> loadContacts() async {
    final r = await _api.get('/chat/contacts');
    if (!r.ok) return const [];
    return r.asList().whereType<Map>().map((e) => ChatContact.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<int?> openWith({required int otherUserId, String? subject}) async {
    final r = await _api.post('/chat/threads', {
      'otherUserId': otherUserId,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
    });
    if (r.ok && r.body is Map) {
      await loadThreads();
      return (r.asMap()['id'] as num?)?.toInt();
    }
    _threadsError = r.errorMessage;
    notifyListeners();
    return null;
  }

  Future<int?> openWithMyDoctor() async {
    final r = await _api.post('/chat/threads/with-my-doctor');
    if (r.ok && r.body is Map) {
      await loadThreads();
      return (r.asMap()['id'] as num?)?.toInt();
    }
    _threadsError = r.errorMessage;
    notifyListeners();
    return null;
  }

  Future<int?> openByPatientId(int patientId, {String? subject}) async {
    final r = await _api.post('/chat/threads/by-patient/$patientId',
        subject == null || subject.isEmpty ? null : {'subject': subject});
    if (r.ok && r.body is Map) {
      await loadThreads();
      return (r.asMap()['id'] as num?)?.toInt();
    }
    _threadsError = r.errorMessage;
    notifyListeners();
    return null;
  }

  Future<void> loadMessages(int threadId) async {
    _msgsLoading[threadId] = true;
    notifyListeners();
    final r = await _api.get('/chat/threads/$threadId/messages');
    if (r.ok) {
      _msgs[threadId] = r.asList().whereType<Map>().map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    _msgsLoading[threadId] = false;
    notifyListeners();
  }

  Future<bool> sendMessage(int threadId, String body,
      {int? linkedReportId, int? linkedRuleExecutionId}) async {
    final r = await _api.post('/chat/threads/$threadId/messages', {
      'body': body,
      if (linkedReportId != null) 'linkedReportId': linkedReportId,
      if (linkedRuleExecutionId != null) 'linkedRuleExecutionId': linkedRuleExecutionId,
    });
    if (r.ok && r.body is Map) {
      _lastSendError = null;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(r.body));
      _msgs.putIfAbsent(threadId, () => <ChatMessage>[]).add(msg);
      notifyListeners();
      return true;
    }
    _lastSendError = r.errorMessage;
    notifyListeners();
    return false;
  }

  Future<ChatThread?> setBlocked(int threadId, bool blocked) async {
    final r = await _api.post('/chat/threads/$threadId/${blocked ? 'block' : 'unblock'}');
    if (r.ok && r.body is Map) {
      final updated = ChatThread.fromJson(Map<String, dynamic>.from(r.body));
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx >= 0) {
        _threads[idx] = updated;
      } else {
        _threads.insert(0, updated);
      }
      notifyListeners();
      return updated;
    }
    return null;
  }

  Future<void> markRead(int threadId) async {
    await _api.post('/chat/threads/$threadId/read');
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx >= 0 && _threads[idx].unreadCount > 0) {
      final prev = _threads[idx];
      _threads[idx] = ChatThread(
        id: prev.id,
        patientUserId: prev.patientUserId,
        doctorUserId: prev.doctorUserId,
        otherDisplayName: prev.otherDisplayName,
        otherRole: prev.otherRole,
        subject: prev.subject,
        lastMessageAt: prev.lastMessageAt,
        unreadCount: 0,
        closed: prev.closed,
      );
      _unreadTotal = _threads.fold(0, (s, t) => s + t.unreadCount);
      notifyListeners();
    }
  }
}
