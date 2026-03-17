import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassDiscussionScreen extends StatefulWidget {
  final String classId;
  final String className;
  final bool embedded;

  const ClassDiscussionScreen({
    super.key,
    required this.classId,
    required this.className,
    this.embedded = false,
  });

  @override
  State<ClassDiscussionScreen> createState() => _ClassDiscussionScreenState();
}

class _ClassDiscussionScreenState extends State<ClassDiscussionScreen> {
  final _client = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  String get _userId => _client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _client
          .from('class_discussions')
          .select('*, profiles(full_name, role)')
          .eq('class_id', widget.classId)
          .order('sent_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _client
        .channel('class_disc_' + widget.classId)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'class_discussions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'class_id',
            value: widget.classId,
          ),
          callback: (payload) async {
            final newMsg = payload.newRecord;
            final senderId = newMsg['sender_id']?.toString() ?? '';
            // Jika dari diri sendiri, replace optimistic entry
            // Jika dari orang lain, fetch profile lalu tambah
            final profile = await _client
                .from('profiles')
                .select('full_name, role')
                .eq('id', senderId)
                .single();
            final full = Map<String, dynamic>.from(newMsg);
            full['profiles'] = profile;
            if (mounted) {
              setState(() {
                if (senderId == _userId) {
                  // Hapus optimistic (id negatif), ganti dengan data real
                  _messages.removeWhere((m) => (m['id'] as int? ?? 0) < 0);
                  _messages.add(full);
                } else {
                  _messages.add(full);
                }
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    // Optimistic update — tampil langsung
    final optimistic = {
      'id': -DateTime.now().millisecondsSinceEpoch,
      'class_id': widget.classId,
      'sender_id': _userId,
      'message': text,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'profiles': {'full_name': 'Saya', 'role': 'optimistic'},
    };
    if (mounted) {
      setState(() => _messages.add(optimistic));
      _scrollToBottom();
    }

    try {
      await _client.from('class_discussions').insert({
        'class_id': widget.classId,
        'sender_id': _userId,
        'message': text,
      });
      // Realtime akan fetch ulang — hapus optimistic dan ganti dengan data real
    } catch (e) {
      // Hapus optimistic jika gagal
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['id'] == optimistic['id']));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal kirim: ' + e.toString()),
                backgroundColor: Colors.red));
        _msgCtrl.text = text; // kembalikan teks
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return h + ':' + m;
    } catch (_) {
      return '';
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Hari ini';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day) {
        return 'Kemarin';
      }
      return dt.day.toString() +
          '/' +
          dt.month.toString() +
          '/' +
          dt.year.toString();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diskusi Kelas',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.className,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ──────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 64, color: Colors.grey.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            const Text('Belum ada diskusi',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            const Text('Mulai diskusi dengan kelas',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg['sender_id'] == _userId;
                          final name =
                              msg['profiles']?['full_name'] ?? 'Unknown';
                          final role = msg['profiles']?['role'] ?? '';
                          final isTeacher = role == 'teacher';

                          // Date separator
                          bool showDate = false;
                          if (i == 0) {
                            showDate = true;
                          } else {
                            final prev = _messages[i - 1];
                            final prevDate = _formatDate(prev['sent_at']);
                            final currDate = _formatDate(msg['sent_at']);
                            if (prevDate != currDate) showDate = true;
                          }

                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Text(
                                        _formatDate(msg['sent_at']),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ]),
                                ),
                              Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    bottom: 6,
                                    left: isMe ? 60 : 0,
                                    right: isMe ? 0 : 60,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 2, left: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(name,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isTeacher
                                                          ? Colors.deepPurple
                                                          : (isDark
                                                              ? Colors.white70
                                                              : Colors
                                                                  .black87))),
                                              if (isTeacher) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.deepPurple
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: const Text('Guru',
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .deepPurple,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.deepPurple
                                              : (isDark
                                                  ? const Color(0xFF2C2C3E)
                                                  : Colors.white),
                                          borderRadius: BorderRadius.only(
                                            topLeft:
                                                const Radius.circular(16),
                                            topRight:
                                                const Radius.circular(16),
                                            bottomLeft: isMe
                                                ? const Radius.circular(16)
                                                : const Radius.circular(4),
                                            bottomRight: isMe
                                                ? const Radius.circular(4)
                                                : const Radius.circular(16),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          msg['message'] ?? '',
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 2, left: 4, right: 4),
                                        child: Text(
                                          _formatTime(msg['sent_at']),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Input ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.deepPurple),
                          tooltip: 'Kirim',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}