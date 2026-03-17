import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  // ── Load semua notif LALU tandai semua sebagai sudah dibaca ──
  // Data tetap ada, hanya badge (is_read) yang berubah
  Future<void> _loadAndMarkRead() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final uid = _client.auth.currentUser?.id ?? '';

      // 1. Load semua notifikasi (termasuk yang sudah dibaca)
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _notifs  = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }

      // 2. Tandai semua sebagai sudah dibaca (hilangkan badge)
      //    Data TIDAK dihapus — tetap terlihat di list
      final hasUnread = _notifs.any((n) => n['is_read'] == false);
      if (hasUnread) {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', uid)
            .eq('is_read', false);

        // Update state lokal agar UI langsung reflect
        if (mounted) {
          setState(() {
            _notifs = _notifs.map((n) => {...n, 'is_read': true}).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _loadAndMarkRead();

  // ── Hapus satu notifikasi ──────────────────────────────────
  Future<void> _deleteOne(int index) async {
    final n = _notifs[index];
    setState(() => _notifs.removeAt(index));
    try {
      await _client.from('notifications').delete().eq('id', n['id']);
    } catch (_) {
      // Kembalikan jika gagal
      setState(() => _notifs.insert(index, n));
    }
  }

  // ── Hapus SEMUA notifikasi ─────────────────────────────────
  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Semua Notifikasi?'),
        content: const Text('Semua riwayat notifikasi akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final uid = _client.auth.currentUser?.id ?? '';
    setState(() => _notifs = []);
    try {
      await _client.from('notifications').delete().eq('user_id', uid);
    } catch (_) {
      _refresh();
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  IconData _icon(String? type) {
    switch (type) {
      case 'submission': return Icons.assignment_turned_in;
      case 'assignment': return Icons.assignment;
      case 'grade':      return Icons.grade;
      case 'material':   return Icons.menu_book;
      default:           return Icons.notifications;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'submission': return Colors.green;
      case 'assignment': return Colors.deepPurple;
      case 'grade':      return Colors.orange;
      case 'material':   return Colors.blue;
      default:           return Colors.grey;
    }
  }

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt   = DateTime.parse(createdAt.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'Baru saja';
      if (diff.inMinutes < 60)  return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24)    return '${diff.inHours} jam lalu';
      if (diff.inDays < 7)      return '${diff.inDays} hari lalu';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (_notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Hapus semua',
              onPressed: _deleteAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Tidak ada notifikasi',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Notifikasi akan muncul di sini',
                          style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifs.length,
                    itemBuilder: (ctx, i) {
                      final n     = _notifs[i];
                      final type  = n['type'] as String?;
                      final color = _color(type);
                      final time  = _timeAgo(n['created_at']);
                      // Semua sudah is_read=true saat layar dibuka
                      // Tapi kita tetap bisa cek untuk transisi visual

                      return Dismissible(
                        key: Key('notif_${n['id']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.white),
                              Text('Hapus', style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                        onDismissed: (_) => _deleteOne(i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.15)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon lingkaran
                              Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    shape: BoxShape.circle),
                                child: Icon(_icon(type), color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              // Konten
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n['body'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    Icon(Icons.access_time,
                                        size: 11, color: Colors.grey.shade400),
                                    const SizedBox(width: 3),
                                    Text(time,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade400)),
                                  ]),
                                ],
                              )),
                              // Warna indikator tipe di kanan
                              Container(
                                width: 4,
                                height: 50,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}