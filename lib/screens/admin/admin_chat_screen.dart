import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/chat_utils.dart';

class AdminChatScreen extends StatefulWidget {
  final VoidCallback? onUnreadChanged;
  const AdminChatScreen({super.key, this.onUnreadChanged});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with UnreadBadgeMixin<AdminChatScreen> {

  final _client = Supabase.instance.client;
  String get _myId => _client.auth.currentUser?.id ?? '';

  @override
  String get badgeMyId => _myId;

  List<Map<String, dynamic>> _guruList = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadContacts(); }

  @override
  void dispose() { stopBadgeListener(); super.dispose(); }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('profiles').select('id, full_name, email')
          .eq('role', 'teacher').order('full_name', ascending: true);
      final list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() { _guruList = list; _loading = false; });
        await loadUnreadCounts(list.map((g) => g['id'] as String).toList());
        startBadgeListener();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_guruList.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("Belum ada guru terdaftar"),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text("Chat dengan Guru",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadContacts,
            child: ListView.builder(
              itemCount: _guruList.length,
              itemBuilder: (ctx, i) {
                final guru = _guruList[i];
                final id = guru['id'] as String;
                final name = guru['full_name'] as String? ?? 'G';
                final unread = unreadMap[id] ?? 0;

                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'G',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                      if (unread > 0) Positioned(top: -4, right: -4, child: UnreadBadge(count: unread)),
                    ],
                  ),
                  title: Text(name,
                      style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(guru['email'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    clearBadge(id);
                    widget.onUnreadChanged?.call();
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _AdminChatRoom(teacherId: id, teacherName: name),
                    ));
                    clearBadge(id);
                    widget.onUnreadChanged?.call();
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
class _AdminChatRoom extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  const _AdminChatRoom({required this.teacherId, required this.teacherName});

  @override
  State<_AdminChatRoom> createState() => _AdminChatRoomState();
}

class _AdminChatRoomState extends State<_AdminChatRoom>
    with ChatRoomMixin<_AdminChatRoom> {
  final _client = Supabase.instance.client;

  @override
  String get myId => _client.auth.currentUser?.id ?? '';
  @override
  String get contactId => widget.teacherId;
  @override
  Color get sendColor => Colors.deepPurple;

  @override
  void initState() { super.initState(); initChat('admin'); }

  @override
  void dispose() { disposeChat(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Text(
              widget.teacherName.isNotEmpty ? widget.teacherName[0].toUpperCase() : 'G',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.teacherName,
                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            const Text('Guru', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
        ]),
      ),
      body: Column(children: [
        Expanded(child: MessageListView(
            messages: messages, scrollCtrl: scrollCtrl,
            myId: myId, accentColor: Colors.green,
            myBubbleColor: Colors.deepPurple.shade100,
            emptyText: "Belum ada pesan. Mulai percakapan!")),
        ChatInputBar(controller: msgCtrl, sending: sending,
            sendColor: Colors.deepPurple, onSend: () => sendMessage(widget.teacherId)),
      ]),
    );
  }
}