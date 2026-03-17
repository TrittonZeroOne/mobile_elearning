import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ══════════════════════════════════════════════════════════════

String buildRoomId(String idA, String idB) {
  final ids = [idA, idB]..sort();
  return '${ids[0]}_${ids[1]}';
}

String formatTime(dynamic sentAt) {
  if (sentAt == null) return '';
  try {
    final dt = DateTime.parse(sentAt.toString()).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

String formatDateSeparator(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Hari Ini';
  if (d == yesterday) return 'Kemarin';
  const bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${date.day} ${bulan[date.month]} ${date.year}';
}

bool isDifferentDay(dynamic prev, dynamic curr) {
  if (prev == null) return true;
  try {
    final p = DateTime.parse(prev.toString()).toLocal();
    final c = DateTime.parse(curr.toString()).toLocal();
    return p.year != c.year || p.month != c.month || p.day != c.day;
  } catch (_) {
    return false;
  }
}

Future<int> getUnreadCount(String roomId, String myId) async {
  try {
    final data = await Supabase.instance.client
        .from('direct_messages')
        .select('id')
        .eq('room_id', roomId)
        .eq('receiver_id', myId)
        .eq('is_read', false);
    return (data as List).length;
  } catch (_) {
    return 0;
  }
}

Future<void> markAllRead(String roomId, String myId) async {
  try {
    await Supabase.instance.client
        .from('direct_messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .eq('receiver_id', myId)
        .eq('is_read', false);
  } catch (_) {}
}

Future<Map<String, String>> fetchProfileNames(List<String> ids) async {
  if (ids.isEmpty) return {};
  try {
    final profiles = await Supabase.instance.client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', ids);
    return {for (final p in profiles) p['id'] as String: p['full_name'] as String? ?? ''};
  } catch (_) {
    return {};
  }
}

Future<List<Map<String, dynamic>>> loadRoomMessages(String roomId, String myId) async {
  final client = Supabase.instance.client;
  final data = await client
      .from('direct_messages')
      .select('id, room_id, sender_id, receiver_id, message, sent_at, is_read')
      .eq('room_id', roomId)
      .order('sent_at', ascending: true);
  final messages = List<Map<String, dynamic>>.from(data);
  final senderIds = messages.map((m) => m['sender_id'] as String).toSet().toList();
  final profileMap = await fetchProfileNames(senderIds);
  for (final msg in messages) {
    msg['sender_name'] = profileMap[msg['sender_id']] ?? '';
  }
  return messages;
}

// ══════════════════════════════════════════════════════════════
// Global: track room ID yang sedang dibuka user
// ══════════════════════════════════════════════════════════════
String? _activeRoomId;
void setActiveRoom(String? roomId) => _activeRoomId = roomId;
bool isRoomActive(String roomId) => _activeRoomId == roomId;

// ══════════════════════════════════════════════════════════════
// MIXIN: auto-update unread badge
// ══════════════════════════════════════════════════════════════
mixin UnreadBadgeMixin<T extends StatefulWidget> on State<T> {
  RealtimeChannel? _badgeChannel;
  final Map<String, int> unreadMap = {};
  String get badgeMyId;

  void startBadgeListener() {
    _badgeChannel?.unsubscribe();
    _badgeChannel = Supabase.instance.client
        .channel('badge_${badgeMyId}_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: badgeMyId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            final senderId = rec['sender_id'] as String?;
            final roomId = rec['room_id'] as String?;
            if (senderId == null || roomId == null) return;
            if (isRoomActive(roomId)) return;
            if (mounted) setState(() => unreadMap[senderId] = (unreadMap[senderId] ?? 0) + 1);
          },
        )
        .subscribe();
  }

  void stopBadgeListener() {
    _badgeChannel?.unsubscribe();
    _badgeChannel = null;
  }

  Future<void> loadUnreadCounts(List<String> contactIds) async {
    if (contactIds.isEmpty) return;
    final counts = await Future.wait(
      contactIds.map((id) => getUnreadCount(buildRoomId(badgeMyId, id), badgeMyId)),
    );
    if (mounted) {
      setState(() {
        for (int i = 0; i < contactIds.length; i++) {
          unreadMap[contactIds[i]] = counts[i];
        }
      });
    }
  }

  void clearBadge(String contactId) {
    if (mounted) setState(() => unreadMap[contactId] = 0);
  }
}

// ══════════════════════════════════════════════════════════════
// MIXIN: logika chat room
// ══════════════════════════════════════════════════════════════
mixin ChatRoomMixin<T extends StatefulWidget> on State<T> {
  final msgCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  List<Map<String, dynamic>> messages = [];
  bool sending = false;
  String myName = '';
  String channelName = '';
  RealtimeChannel? _channel;

  String get myId;
  String get contactId;
  String get roomId => buildRoomId(myId, contactId);
  Color get sendColor;

  Future<void> initChat(String prefix) async {
    channelName = '${prefix}_$roomId';
    setActiveRoom(roomId);
    try {
      final data = await Supabase.instance.client
          .from('profiles').select('full_name').eq('id', myId).single();
      myName = data['full_name'] as String? ?? '';
    } catch (_) {}
    await markAllRead(roomId, myId);
    await _loadMessages();
    _subscribe();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await loadRoomMessages(roomId, myId);
      if (mounted) {
        setState(() => messages = msgs);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('loadMessages error: $e');
    }
  }

  void _subscribe() {
    _channel = Supabase.instance.client.channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (payload) async {
            final newRecord = Map<String, dynamic>.from(payload.newRecord);
            final senderId = newRecord['sender_id'] as String?;
            if (senderId == myId) {
              final names = await fetchProfileNames([myId]);
              newRecord['sender_name'] = names[myId] ?? myName;
              if (mounted) {
                setState(() {
                  messages = messages.where((m) => m['_optimistic'] != true).toList();
                  final exists = messages.any((m) => m['id'] == newRecord['id']);
                  if (!exists) messages = [...messages, newRecord];
                });
                _scrollToBottom();
              }
            } else {
              await markAllRead(roomId, myId);
              final names = await fetchProfileNames([senderId!]);
              newRecord['sender_name'] = names[senderId] ?? '';
              newRecord['is_read'] = true;
              if (mounted) {
                setState(() {
                  final exists = messages.any((m) => m['id'] == newRecord['id']);
                  if (!exists) messages = [...messages, newRecord];
                });
                _scrollToBottom();
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (payload) {
            final updated = payload.newRecord;
            if (mounted) {
              setState(() {
                messages = messages.map((m) {
                  if (m['id'] == updated['id']) return {...m, 'is_read': updated['is_read']};
                  return m;
                }).toList();
              });
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients && scrollCtrl.position.hasContentDimensions) {
        scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> sendMessage(String receiverId) async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty || sending) return;
    msgCtrl.clear();
    setState(() => sending = true);
    final optimistic = <String, dynamic>{
      'id': null, 'room_id': roomId, 'sender_id': myId,
      'receiver_id': receiverId, 'message': text,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': false, 'sender_name': myName, '_optimistic': true,
    };
    setState(() => messages = [...messages, optimistic]);
    _scrollToBottom();
    try {
      await Supabase.instance.client.from('direct_messages').insert({
        'room_id': roomId, 'sender_id': myId, 'receiver_id': receiverId,
        'message': text, 'sent_at': optimistic['sent_at'], 'is_read': false,
      });
    } catch (e) {
      if (mounted) {
        setState(() => messages = messages.where((m) => m['_optimistic'] != true).toList());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal kirim: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void disposeChat() {
    setActiveRoom(null);
    markAllRead(roomId, myId);
    msgCtrl.dispose();
    scrollCtrl.dispose();
    _channel?.unsubscribe();
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════

class DateSeparator extends StatelessWidget {
  final String label;
  const DateSeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Expanded(child: Divider()),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            // ← FIX: abu gelap di dark mode, abu muda di light mode
            color: isDark ? const Color(0xFF2C2C3E) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  // ← FIX: teks terlihat di kedua mode
                  color: isDark ? Colors.white60 : Colors.grey.shade600)),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final Color accentColor;
  final Color myBubbleColor;

  const ChatBubble({super.key, required this.msg, required this.isMe,
      required this.accentColor, required this.myBubbleColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final senderName = msg['sender_name'] as String? ?? '';
    final isOptimistic = msg['_optimistic'] == true;

    // ← FIX: bubble kiri (received) - gelap di dark mode, terang di light mode
    final receivedBubbleColor = isDark ? const Color(0xFF2C2C3E) : Colors.grey.shade200;
    // ← FIX: teks bubble kiri - putih di dark, hitam di light
    final receivedTextColor = isDark ? Colors.white : Colors.black87;
    // ← FIX: teks bubble kanan (sent) - selalu gelap karena background terang
    final sentTextColor = isDark ? Colors.black87 : Colors.black87;
    // ← FIX: timestamp received (kiri)
    final timeColor = isDark ? Colors.white60 : Colors.grey;
    // ← FIX: timestamp sent (kanan) - bubble terang, pakai warna gelap kontras
    final sentTimeColor = Colors.black54;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: isOptimistic ? 0.65 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: isMe ? myBubbleColor : receivedBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(senderName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)),
                ),
              Text(msg['message'] ?? '',
                  style: TextStyle(fontSize: 14,
                      // ← FIX: teks pesan terlihat di kedua mode
                      color: isMe ? sentTextColor : receivedTextColor)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatTime(msg['sent_at']),
                    // ← FIX: timestamp terlihat di kedua mode
                    style: TextStyle(fontSize: 10, color: isMe ? sentTimeColor : timeColor)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  isOptimistic
                      ? Icon(Icons.access_time, size: 12, color: sentTimeColor)
                      : Icon(
                          msg['is_read'] == true ? Icons.done_all : Icons.done,
                          size: 12,
                          color: msg['is_read'] == true ? Colors.blue : sentTimeColor,
                        ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text(count > 99 ? '99+' : count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Color sendColor;
  final VoidCallback onSend;

  const ChatInputBar({super.key, required this.controller, required this.sending,
      required this.sendColor, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // ← FIX: background input bar
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          // ← FIX: teks input terlihat di dark mode
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "Tulis pesan...",
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
            filled: true,
            // ← FIX: fill color input field
            fillColor: isDark ? const Color(0xFF2C2C3E) : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => onSend(),
        )),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: sendColor,
          child: sending
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: onSend),
        ),
      ]),
    );
  }
}

class MessageListView extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController scrollCtrl;
  final String myId;
  final Color accentColor;
  final Color myBubbleColor;
  final String emptyText;

  const MessageListView({super.key, required this.messages, required this.scrollCtrl,
      required this.myId, required this.accentColor, required this.myBubbleColor,
      this.emptyText = "Mulai percakapan"});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return Center(child: Text(emptyText));
    final List<Widget> items = [];
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final prevSentAt = i > 0 ? messages[i - 1]['sent_at'] : null;
      if (isDifferentDay(prevSentAt, msg['sent_at'])) {
        DateTime? dt;
        try { dt = DateTime.parse(msg['sent_at'].toString()).toLocal(); } catch (_) {}
        if (dt != null) items.add(DateSeparator(label: formatDateSeparator(dt)));
      }
      items.add(ChatBubble(msg: msg, isMe: msg['sender_id'] == myId,
          accentColor: accentColor, myBubbleColor: myBubbleColor));
    }
    return ListView(controller: scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: items);
  }
}