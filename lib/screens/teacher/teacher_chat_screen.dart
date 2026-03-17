import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';
import '../shared/chat_utils.dart';

class TeacherChatScreen extends StatefulWidget {
  final VoidCallback? onUnreadChanged;
  const TeacherChatScreen({super.key, this.onUnreadChanged});

  @override
  State<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends State<TeacherChatScreen>
    with UnreadBadgeMixin<TeacherChatScreen> {

  final _client = Supabase.instance.client;
  String get _myId => _client.auth.currentUser?.id ?? '';

  @override
  String get badgeMyId => _myId;

  List<Map<String, dynamic>> _adminList = [];
  List<Map<String, dynamic>> _siswaList = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadContacts(); }

  @override
  void dispose() { stopBadgeListener(); super.dispose(); }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final service = SupabaseService();
      final subjects = await service.getSubjects(
        UserProfile(id: _myId, email: '', fullName: '', role: 'teacher'),
      );

      final Map<String, Map<String, dynamic>> siswaMap = {};
      final Set<String> classIds = {};
      for (final sub in subjects) {
        final cid = sub['class_id'] as String?;
        if (cid != null) classIds.add(cid);
      }

      final Map<String, String> classNameMap = {};
      if (classIds.isNotEmpty) {
        final kelasData = await _client.from('classes').select('id, name').inFilter('id', classIds.toList());
        for (final k in kelasData) {
          classNameMap[k['id'] as String] = k['name'] as String? ?? '';
        }
      }

      for (final cid in classIds) {
        final students = await service.getStudentsForClass(cid);
        final kelasName = classNameMap[cid] ?? '';
        for (final s in students) {
          siswaMap[s['id'] as String] = {...s, 'type': 'student', 'class_name': kelasName};
        }
      }

      final admins = await _client.from('profiles').select().eq('role', 'admin');
      final adminList = List<Map<String, dynamic>>.from(admins).map((a) => {...a, 'type': 'admin'}).toList();
      final siswaList = siswaMap.values.toList()
        ..sort((a, b) => (a['full_name'] as String? ?? '').compareTo(b['full_name'] as String? ?? ''));

      if (mounted) {
        setState(() { _adminList = adminList; _siswaList = siswaList; _loading = false; });
        final allIds = [...adminList, ...siswaList].map((c) => c['id'] as String).toList();
        await loadUnreadCounts(allIds);
        startBadgeListener();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Icon(icon, color: color, size: 18), const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8), const Expanded(child: Divider()),
      ]),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact, Color color) {
    final id = contact['id'] as String;
    final name = contact['full_name'] as String? ?? '';
    final isAdmin = contact['type'] == 'admin';
    final className = contact['class_name'] as String? ?? '';
    final unread = unreadMap[id] ?? 0;

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          if (unread > 0) Positioned(top: -4, right: -4, child: UnreadBadge(count: unread)),
        ],
      ),
      title: Text(name, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(
        isAdmin ? 'Administrator' : (className.isNotEmpty ? 'Siswa $className' : 'Siswa'),
        style: TextStyle(fontSize: 12, color: color),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        clearBadge(id);
        widget.onUnreadChanged?.call();
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => _TeacherChatRoom(contactId: id, contactName: name, contactRole: contact['type'] as String),
        ));
        clearBadge(id);
        widget.onUnreadChanged?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_adminList.isEmpty && _siswaList.isEmpty) {
      return const Center(child: Text("Belum ada kontak tersedia."));
    }
    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView(children: [
        if (_adminList.isNotEmpty) ...[
          _buildSectionHeader("Admin", Icons.admin_panel_settings, Colors.deepPurple),
          ..._adminList.map((a) => _buildContactTile(a, Colors.deepPurple)),
        ],
        if (_siswaList.isNotEmpty) ...[
          _buildSectionHeader("Siswa", Icons.person, Colors.blue),
          ..._siswaList.map((s) => _buildContactTile(s, Colors.blue)),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
class _TeacherChatRoom extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String contactRole;
  const _TeacherChatRoom({required this.contactId, required this.contactName, required this.contactRole});

  @override
  State<_TeacherChatRoom> createState() => _TeacherChatRoomState();
}

class _TeacherChatRoomState extends State<_TeacherChatRoom>
    with ChatRoomMixin<_TeacherChatRoom> {
  final _client = Supabase.instance.client;

  @override
  String get myId => _client.auth.currentUser?.id ?? '';
  @override
  String get contactId => widget.contactId;
  @override
  Color get sendColor => Colors.green;

  Color get _accentColor => widget.contactRole == 'admin' ? Colors.deepPurple : Colors.blue;

  @override
  void initState() { super.initState(); initChat('teacher'); }

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
              widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.contactName,
                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text(widget.contactRole == 'admin' ? 'Administrator' : 'Siswa',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
        ]),
      ),
      body: Column(children: [
        Expanded(child: MessageListView(
            messages: messages, scrollCtrl: scrollCtrl,
            myId: myId, accentColor: _accentColor,
            myBubbleColor: Colors.green.shade100,
            emptyText: "Mulai percakapan")),
        ChatInputBar(controller: msgCtrl, sending: sending,
            sendColor: Colors.green, onSend: () => sendMessage(widget.contactId)),
      ]),
    );
  }
}