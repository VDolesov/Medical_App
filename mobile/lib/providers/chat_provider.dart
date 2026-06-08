import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_provider.dart';

class ChatThread {
  final int id;
  final int patientUserId;
  final int doctorUserId;
  final int? patientId;
  final String? subject;
  final bool closed;
  final DateTime? lastMessageAt;
  final String? otherDisplayName;
  final String? otherRole;
  final int unreadCount;
  final bool blocked;
  final bool blockedByCurrentUser;
  final bool blockedByOtherUser;
  final String? blockedByRole;
  final DateTime? blockedAt;

  ChatThread({
    required this.id,
    required this.patientUserId,
    required this.doctorUserId,
    this.patientId,
    this.subject,
    required this.closed,
    this.lastMessageAt,
    this.otherDisplayName,
    this.otherRole,
    required this.unreadCount,
    required this.blocked,
    required this.blockedByCurrentUser,
    required this.blockedByOtherUser,
    this.blockedByRole,
    this.blockedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    DateTime? ts;
    final raw = json['lastMessageAt'];
    if (raw is String && raw.isNotEmpty) {
      ts = DateTime.tryParse(raw);
    }
    DateTime? blockedTs;
    final rawBlocked = json['blockedAt'];
    if (rawBlocked is String && rawBlocked.isNotEmpty) {
      blockedTs = DateTime.tryParse(rawBlocked);
    }
    return ChatThread(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patientUserId: (json['patientUserId'] as num?)?.toInt() ?? 0,
      doctorUserId: (json['doctorUserId'] as num?)?.toInt() ?? 0,
      patientId: (json['patientId'] as num?)?.toInt(),
      subject: json['subject']?.toString(),
      closed: json['closed'] == true,
      lastMessageAt: ts,
      otherDisplayName: json['otherDisplayName']?.toString(),
      otherRole: json['otherRole']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      blocked: json['blocked'] == true,
      blockedByCurrentUser: json['blockedByCurrentUser'] == true,
      blockedByOtherUser: json['blockedByOtherUser'] == true,
      blockedByRole: json['blockedByRole']?.toString(),
      blockedAt: blockedTs,
    );
  }

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
      patientId: patientId,
      subject: subject,
      closed: closed,
      lastMessageAt: lastMessageAt,
      otherDisplayName: otherDisplayName,
      otherRole: otherRole,
      unreadCount: unreadCount ?? this.unreadCount,
      blocked: blocked ?? this.blocked,
      blockedByCurrentUser: blockedByCurrentUser ?? this.blockedByCurrentUser,
      blockedByOtherUser: blockedByOtherUser ?? this.blockedByOtherUser,
      blockedByRole: blockedByRole ?? this.blockedByRole,
      blockedAt: blockedAt ?? this.blockedAt,
    );
  }
}

class ChatMessage {
  final int id;
  final int threadId;
  final int senderUserId;
  final String? senderRole;
  final String? senderDisplayName;
  final String body;
  final int? linkedReportId;
  final int? linkedRuleExecutionId;
  final bool readByRecipient;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    this.senderRole,
    this.senderDisplayName,
    required this.body,
    this.linkedReportId,
    this.linkedRuleExecutionId,
    required this.readByRecipient,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? ts;
    final raw = json['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      ts = DateTime.tryParse(raw);
    }
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      threadId: (json['threadId'] as num?)?.toInt() ?? 0,
      senderUserId: (json['senderUserId'] as num?)?.toInt() ?? 0,
      senderRole: json['senderRole']?.toString(),
      senderDisplayName: json['senderDisplayName']?.toString(),
      body: json['body']?.toString() ?? '',
      linkedReportId: (json['linkedReportId'] as num?)?.toInt(),
      linkedRuleExecutionId: (json['linkedRuleExecutionId'] as num?)?.toInt(),
      readByRecipient: json['readByRecipient'] == true,
      createdAt: ts,
    );
  }
}

class ChatContact {
  final int userId;
  final String role;
  final String displayName;

  ChatContact({required this.userId, required this.role, required this.displayName});

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      role: json['role']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '?',
    );
  }
}

class ChatProvider with ChangeNotifier {
  static const String _baseUrl = ApiConfig.baseUrl;

  List<ChatThread> _threads = [];
  bool _threadsLoading = false;
  String? _threadsError;
  int _unreadTotal = 0;

  final Map<int, List<ChatMessage>> _messagesByThread = {};
  final Map<int, bool> _messagesLoading = {};
  final Map<int, String?> _messagesError = {};

  List<ChatThread> get threads => List.unmodifiable(_threads);
  bool get threadsLoading => _threadsLoading;
  String? get threadsError => _threadsError;
  int get unreadTotal => _unreadTotal;

  List<ChatMessage> messagesFor(int threadId) =>
      List.unmodifiable(_messagesByThread[threadId] ?? const <ChatMessage>[]);
  ChatThread? threadById(int threadId) {
    for (final t in _threads) {
      if (t.id == threadId) return t;
    }
    return null;
  }
  bool messagesLoading(int threadId) => _messagesLoading[threadId] == true;
  String? messagesError(int threadId) => _messagesError[threadId];

  Map<String, String> _authHeaders(AuthProvider auth) => {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json; charset=utf-8',
      };

  Future<void> loadThreads(AuthProvider auth) async {
    if (auth.token == null) return;
    _threadsLoading = true;
    _threadsError = null;
    notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/chat/threads'),
        headers: _authHeaders(auth),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          _threads = decoded
              .whereType<Map>()
              .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _unreadTotal = _threads.fold(0, (s, t) => s + t.unreadCount);
        }
      } else {
        _threadsError = 'Чаты: HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _threadsError = 'Ошибка загрузки чатов: $e';
    } finally {
      _threadsLoading = false;
      notifyListeners();
    }
  }

  Future<int?> openThreadWith(AuthProvider auth, {required int otherUserId, String? subject}) async {
    return _openThreadInternal(auth, '$_baseUrl/chat/threads', {
      'otherUserId': otherUserId,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
    });
  }

Future<List<ChatContact>> loadContacts(AuthProvider auth) async {
    if (auth.token == null) return const [];
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/chat/contacts'),
        headers: _authHeaders(auth),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => ChatContact.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('loadContacts error: $e');
    }
    return const [];
  }

Future<int?> openThreadByPatientId(AuthProvider auth, {required int patientId, String? subject}) async {
    return _openThreadInternal(auth, '$_baseUrl/chat/threads/by-patient/$patientId',
        subject == null || subject.isEmpty ? <String, dynamic>{} : {'subject': subject});
  }

Future<int?> openThreadWithMyDoctor(AuthProvider auth, {String? subject}) async {
    return _openThreadInternal(auth, '$_baseUrl/chat/threads/with-my-doctor',
        subject == null || subject.isEmpty ? <String, dynamic>{} : {'subject': subject});
  }

  Future<int?> _openThreadInternal(AuthProvider auth, String url, Map<String, dynamic> body) async {
    if (auth.token == null) return null;
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: _authHeaders(auth),
        body: json.encode(body),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map && decoded['id'] is num) {
          await loadThreads(auth);
          return (decoded['id'] as num).toInt();
        }
      } else {
        try {
          final decoded = json.decode(utf8.decode(resp.bodyBytes));
          if (decoded is Map && decoded['error'] != null) {
            _threadsError = decoded['error'].toString();
            notifyListeners();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('openThread error: $e');
    }
    return null;
  }

  Future<void> loadMessages(AuthProvider auth, int threadId) async {
    if (auth.token == null) return;
    _messagesLoading[threadId] = true;
    _messagesError[threadId] = null;
    notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/chat/threads/$threadId/messages'),
        headers: _authHeaders(auth),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          _messagesByThread[threadId] = decoded
              .whereType<Map>()
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } else {
        _messagesError[threadId] = 'Сообщения: HTTP ${resp.statusCode}';
      }
    } catch (e) {
      _messagesError[threadId] = 'Ошибка: $e';
    } finally {
      _messagesLoading[threadId] = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(AuthProvider auth, int threadId, String body,
      {int? linkedReportId, int? linkedRuleExecutionId}) async {
    if (auth.token == null || body.trim().isEmpty) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/chat/threads/$threadId/messages'),
        headers: _authHeaders(auth),
        body: json.encode({
          'body': body.trim(),
          if (linkedReportId != null) 'linkedReportId': linkedReportId,
          if (linkedRuleExecutionId != null) 'linkedRuleExecutionId': linkedRuleExecutionId,
        }),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(decoded);
          final list = _messagesByThread.putIfAbsent(threadId, () => <ChatMessage>[]);
          list.add(msg);
          notifyListeners();
          return true;
        }
      } else {
        _messagesError[threadId] = _extractError(resp) ?? 'Сообщение: HTTP ${resp.statusCode}';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
    return false;
  }

  Future<bool> blockThread(AuthProvider auth, int threadId) {
    return _setThreadBlocked(auth, threadId, true);
  }

  Future<bool> unblockThread(AuthProvider auth, int threadId) {
    return _setThreadBlocked(auth, threadId, false);
  }

  Future<bool> _setThreadBlocked(AuthProvider auth, int threadId, bool blocked) async {
    if (auth.token == null) return false;
    try {
      final action = blocked ? 'block' : 'unblock';
      final resp = await http.post(
        Uri.parse('$_baseUrl/chat/threads/$threadId/$action'),
        headers: _authHeaders(auth),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map) {
          _upsertThread(ChatThread.fromJson(Map<String, dynamic>.from(decoded)));
          return true;
        }
      } else {
        _threadsError = _extractError(resp) ?? 'Чат: HTTP ${resp.statusCode}';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('setThreadBlocked error: $e');
    }
    return false;
  }

  Future<void> markRead(AuthProvider auth, int threadId) async {
    if (auth.token == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/chat/threads/$threadId/read'),
        headers: _authHeaders(auth),
      );
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx >= 0 && _threads[idx].unreadCount > 0) {
        final prev = _threads[idx];
        _threads[idx] = prev.copyWith(unreadCount: 0);
        _unreadTotal = _threads.fold(0, (s, t) => s + t.unreadCount);
        notifyListeners();
      }
    } catch (_) {

    }
  }

  Future<int> refreshUnreadCount(AuthProvider auth) async {
    if (auth.token == null) return 0;
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/chat/unread-count'),
        headers: _authHeaders(auth),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map && decoded['unread'] is num) {
          _unreadTotal = (decoded['unread'] as num).toInt();
          notifyListeners();
        }
      }
    } catch (_) {}
    return _unreadTotal;
  }

  void clear() {
    _threads = [];
    _threadsError = null;
    _threadsLoading = false;
    _unreadTotal = 0;
    _messagesByThread.clear();
    _messagesLoading.clear();
    _messagesError.clear();
    notifyListeners();
  }

  void _upsertThread(ChatThread thread) {
    final idx = _threads.indexWhere((t) => t.id == thread.id);
    if (idx >= 0) {
      _threads[idx] = thread;
    } else {
      _threads.add(thread);
    }
    _unreadTotal = _threads.fold(0, (s, t) => s + t.unreadCount);
    notifyListeners();
  }

  String? _extractError(http.Response resp) {
    try {
      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return null;
  }
}
