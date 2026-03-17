import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'course_detail.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final client = Supabase.instance.client;
  final service = SupabaseService();

  Future<Map<String, dynamic>> _loadHomeData() async {
    final user = client.auth.currentUser!;
    final profile = await service.getProfile(user.id);
    final allSubjects = await service.getSubjects(profile);

    final hariIni = _hariIndonesia(DateTime.now().weekday);

    // Debug: print semua schedule_day yang ada
    print('=== DEBUG hari ini: $hariIni ===');
    for (final s in allSubjects) {
      print('Mapel: ${s['name']} | schedule_day: "${s['schedule_day']}"');
    }

    final jadwalHariIni = allSubjects
        .where((s) => (s['schedule_day'] as String?)?.trim() == hariIni.trim())
        .toList();

    final announcements = await client
        .from('announcements')
        .select('*, profiles(full_name)')
        .or('target.eq.all,target.eq.student')
        .order('created_at', ascending: false)
        .limit(5);

    return {
      'profile': profile,
      'jadwal': jadwalHariIni,
      'announcements': List<Map<String, dynamic>>.from(announcements),
      'hariIni': hariIni,
    };
  }

  String _hariIndonesia(int weekday) {
    const hari = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu',
      4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Minggu'
    };
    return hari[weekday] ?? '';
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadHomeData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

        final data = snapshot.data!;
        final profile = data['profile'];
        final jadwal = data['jadwal'] as List;
        final announcements = data['announcements'] as List;
        final hariIni = data['hariIni'] as String;

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Greeting card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Text(
                        (profile.fullName.isNotEmpty ? profile.fullName[0] : 'S').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Halo, ${profile.fullName}!",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Selamat belajar hari $hariIni",
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pengumuman
              _SectionHeader(icon: Icons.campaign, label: "Pengumuman", color: Colors.red),
              const SizedBox(height: 8),
              if (announcements.isEmpty)
                _EmptyCard(icon: Icons.notifications_none, text: "Belum ada pengumuman", color: Colors.grey)
              else
                ...announcements.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign, color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(a['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold))),
                            Text(_formatDate(a['created_at']),
                                style: TextStyle(fontSize: 11,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white54 : Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(a['body'] ?? '', style: const TextStyle(fontSize: 13)),
                        if (a['profiles'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text("— ${a['profiles']['full_name']}",
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                )),
                              
                const SizedBox(height: 20),

                // Jadwal hari ini
              _SectionHeader(icon: Icons.schedule, label: "Jadwal Hari Ini ($hariIni)", color: Colors.deepPurple),
              const SizedBox(height: 8),
              if (jadwal.isEmpty)
                _EmptyCard(icon: Icons.celebration, text: "Tidak ada jadwal hari ini 🎉", color: Colors.orange)
              else
                ...jadwal.map((sub) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.withOpacity(0.15),
                      child: const Icon(Icons.book, color: Colors.deepPurple, size: 18),
                    ),
                    title: Text(sub['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: sub['schedule_time'] != null
                        ? Row(children: [
                            Icon(Icons.access_time, size: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white54 : Colors.grey),
                            const SizedBox(width: 4),
                            Text(sub['schedule_time'], style: const TextStyle(fontSize: 12)),
                          ])
                        : null,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CourseDetail(
                        subjectId: sub['id'] as int,
                        subjectName: sub['name'] as String? ?? '',
                        classId: sub['class_id']?.toString() ?? '',
                      ),
                    )),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _EmptyCard({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C3E)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}