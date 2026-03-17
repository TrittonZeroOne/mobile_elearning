import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _client = Supabase.instance.client;
  bool _loading = true;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _todaySubjects = [];

  // Nama hari dalam bahasa Indonesia
  static const _hariMap = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };

  String get _hariIni => _hariMap[DateTime.now().weekday] ?? '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final user = _client.auth.currentUser!;

      // Load profile
      final profileData =
          await _client.from('profiles').select().eq('id', user.id).single();

      // Load pengumuman (target: teacher atau all)
      final announcementData = await _client
          .from('announcements')
          .select('*, profiles(full_name)')
          .or('target.eq.teacher,target.eq.all')
          .order('created_at', ascending: false)
          .limit(5);

      // Load semua mapel guru ini
      final service = SupabaseService();
      final allSubjects = await service.getSubjects(
        UserProfile(
            id: user.id, email: '', fullName: '', role: 'teacher'),
      );

      // Filter hanya yang hari ini
      final todaySubjects = allSubjects
          .where((s) => s['schedule_day'] == _hariIni)
          .toList();

      // Urutkan berdasarkan jam mulai
      todaySubjects.sort((a, b) {
        final ta = _parseTime(a['schedule_time']);
        final tb = _parseTime(b['schedule_time']);
        return ta.compareTo(tb);
      });

      if (mounted) {
        setState(() {
          _profile = profileData;
          _announcements = List<Map<String, dynamic>>.from(announcementData);
          _todaySubjects = todaySubjects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Parse jam mulai dari format "08:00 - 09:30" → "08:00" → int untuk sorting
  int _parseTime(dynamic scheduleTime) {
    if (scheduleTime == null) return 9999;
    final parts = scheduleTime.toString().split(' - ');
    if (parts.isEmpty) return 9999;
    final timeParts = parts[0].trim().split(':');
    if (timeParts.length < 2) return 9999;
    final h = int.tryParse(timeParts[0]) ?? 99;
    final m = int.tryParse(timeParts[1]) ?? 99;
    return h * 60 + m;
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Color _targetColor(String? target) {
    switch (target) {
      case 'student': return Colors.blue;
      case 'teacher': return Colors.green;
      default: return Colors.deepPurple;
    }
  }

  String _targetLabel(String? target) {
    switch (target) {
      case 'student': return 'Siswa';
      case 'teacher': return 'Guru';
      default: return 'Semua';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final name = _profile?['full_name'] as String? ?? 'Guru';
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Greeting ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang,',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_hariIni, ${now.day}/${now.month}/${now.year}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Pengumuman ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.campaign,
            title: 'Pengumuman Terbaru',
            color: Colors.red,
          ),
          const SizedBox(height: 8),
          if (_announcements.isEmpty)
            _EmptyCard(
              icon: Icons.notifications_none,
              message: 'Belum ada pengumuman',
            )
          else
            ..._announcements.map((a) {
              final color = _targetColor(a['target']);
              final senderName =
                  a['profiles']?['full_name'] as String? ?? 'Admin';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign, color: color, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(a['title'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_targetLabel(a['target']),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(a['body'] ?? '',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Dari: $senderName',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey)),
                          Text(_formatDate(a['created_at']),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

          // ── Jadwal Hari Ini ───────────────────────────────────
          _SectionHeader(
            icon: Icons.today,
            title: 'Jadwal Mengajar Hari Ini',
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          if (_todaySubjects.isEmpty)
            _EmptyCard(
              icon: Icons.event_available,
              message: 'Tidak ada jadwal mengajar hari ini',
            )
          else
            ..._todaySubjects.map((sub) {
              final kelasName =
                  sub['classes']?['name'] as String? ?? 'Tanpa Kelas';
              final scheduleTime = sub['schedule_time'] as String? ?? '';
              final isOngoing = _isClassOngoing(sub['schedule_time']);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isOngoing
                      ? const BorderSide(color: Colors.green, width: 2)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isOngoing ? Colors.green : Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('Kelas: $kelasName',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey)),
                            if (scheduleTime.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 12,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(scheduleTime,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey)),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (isOngoing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text('Sedang Berlangsung',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          
        ],
      ),
    );
  }

  /// Cek apakah kelas sedang berlangsung sekarang
  bool _isClassOngoing(dynamic scheduleTime) {
    if (scheduleTime == null) return false;
    try {
      final parts = scheduleTime.toString().split(' - ');
      if (parts.length < 2) return false;

      final now = DateTime.now();
      final startParts = parts[0].trim().split(':');
      final endParts = parts[1].trim().split(':');

      final start = DateTime(now.year, now.month, now.day,
          int.parse(startParts[0]), int.parse(startParts[1]));
      final end = DateTime(now.year, now.month, now.day,
          int.parse(endParts[0]), int.parse(endParts[1]));

      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 28),
          const SizedBox(width: 12),
          Text(message,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}