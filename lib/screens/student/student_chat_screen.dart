import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../shared/chat_utils.dart';

class StudentChatScreen extends StatefulWidget {
  final VoidCallback? onUnreadChanged;
  const StudentChatScreen({super.key, this.onUnreadChanged});

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen>
    with UnreadBadgeMixin<StudentChatScreen> {

  final _client = Supabase.instance.client;
  String get _myId => _client.auth.currentUser?.id ?? '';

  @override
  String get badgeMyId => _myId;

  List<Map<String, dynamic>> _guruList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGuru();
  }

  @override
  void dispose() {
    stopBadgeListener();
    super.dispose();
  }

  Future<void> _loadGuru() async {
    setState(() => _loading = true);
    try {
      final service = SupabaseService();
      final profile = await service.getProfile(_myId);
      final subjects = await service.getSubjects(profile);

      final Map<String, Map<String, dynamic>> guruMap = {};
      for (final sub in subjects) {
        final teacherId = sub['teacher_id'] as String?;
        if (teacherId != null && sub['profiles'] != null) {
          guruMap[teacherId] = {
            'teacher_id': teacherId,
            'id': teacherId,
            'full_name': sub['profiles']['full_name'] ?? '',
            'subject_name': sub['name'] ?? '',
          };
        }
      }

      final list = guruMap.values.toList()
        ..sort((a, b) => (a['full_name'] as String).compareTo(b['full_name'] as String));

      if (mounted) {
        setState(() { _guruList = list; _loading = false; });
        await loadUnreadCounts(list.map((g) => g['teacher_id'] as String).toList());
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
          Text("Belum ada guru yang mengajar"),
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
            onRefresh: _loadGuru,
            child: ListView.builder(
              itemCount: _guruList.length,
              itemBuilder: (ctx, i) {
                final guru = _guruList[i];
                final teacherId = guru['teacher_id'] as String;
                final name = guru['full_name'] as String;
                final unread = unreadMap[teacherId] ?? 0;

                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'G',
                            style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                      ),
                      if (unread > 0)
                        Positioned(top: -4, right: -4, child: UnreadBadge(count: unread)),
                    ],
                  ),
                  title: Text(name,
                      style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text("Guru ${guru['subject_name']}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    clearBadge(teacherId);
                    widget.onUnreadChanged?.call();
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _StudentChatRoom(
                        teacherId: teacherId,
                        teacherName: name,
                        subjectName: guru['subject_name'] as String,
                      ),
                    ));
                    clearBadge(teacherId);
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
class _StudentChatRoom extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String subjectName;
  const _StudentChatRoom({required this.teacherId, required this.teacherName,
      required this.subjectName});

  @override
  State<_StudentChatRoom> createState() => _StudentChatRoomState();
}

class _StudentChatRoomState extends State<_StudentChatRoom>
    with ChatRoomMixin<_StudentChatRoom> {
  final _client = Supabase.instance.client;

  @override
  String get myId => _client.auth.currentUser?.id ?? '';
  @override
  String get contactId => widget.teacherId;
  @override
  Color get sendColor => Colors.deepPurple;

  @override
  void initState() { super.initState(); initChat('student'); }

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
            Text(widget.subjectName,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
      body: Column(children: [
        Expanded(child: MessageListView(
            messages: messages, scrollCtrl: scrollCtrl,
            myId: myId, accentColor: Colors.deepPurple,
            myBubbleColor: Colors.deepPurple.shade100,
            emptyText: "Mulai percakapan dengan guru")),
        ChatInputBar(controller: msgCtrl, sending: sending,
            sendColor: Colors.deepPurple, onSend: () => sendMessage(widget.teacherId)),
      ]),
    );
  }
}