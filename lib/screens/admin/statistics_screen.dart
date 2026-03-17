import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final client = Supabase.instance.client;
  bool _loading = true;

  int _totalSiswa = 0, _totalGuru = 0, _totalKelas = 0, _totalMapel = 0;
  int _totalMateri = 0, _totalTugas = 0, _totalSubmisi = 0, _totalAbsensi = 0;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        client.from('profiles').select('id').eq('role', 'student'),
        client.from('profiles').select('id').eq('role', 'teacher'),
        client.from('classes').select('id'),
        client.from('subjects').select('id'),
        client.from('materials').select('id'),
        client.from('assignments').select('id'),
        client.from('submissions').select('id'),
        client.from('attendances').select('id'),
      ]);
      setState(() {
        _totalSiswa = (results[0] as List).length;
        _totalGuru = (results[1] as List).length;
        _totalKelas = (results[2] as List).length;
        _totalMapel = (results[3] as List).length;
        _totalMateri = (results[4] as List).length;
        _totalTugas = (results[5] as List).length;
        _totalSubmisi = (results[6] as List).length;
        _totalAbsensi = (results[7] as List).length;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistik Aplikasi"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header gradient - teks selalu putih, aman
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bar_chart, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Statistik Penggunaan",
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("Data terkini aplikasi e-learning",
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _SectionTitle(title: "Pengguna", icon: Icons.people),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _StatCard(icon: Icons.person, label: "Siswa", value: _totalSiswa, color: Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.school, label: "Guru", value: _totalGuru, color: Colors.green)),
                  ]),
                  const SizedBox(height: 20),

                  _SectionTitle(title: "Akademik", icon: Icons.menu_book),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _StatCard(icon: Icons.class_, label: "Kelas", value: _totalKelas, color: Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.book, label: "Mata Pelajaran", value: _totalMapel, color: Colors.purple)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatCard(icon: Icons.picture_as_pdf, label: "Materi", value: _totalMateri, color: Colors.red)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.assignment, label: "Tugas", value: _totalTugas, color: Colors.teal)),
                  ]),
                  const SizedBox(height: 20),

                  _SectionTitle(title: "Aktivitas", icon: Icons.trending_up),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _StatCard(icon: Icons.upload_file, label: "Pengumpulan", value: _totalSubmisi, color: Colors.indigo)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.how_to_reg, label: "Absensi", value: _totalAbsensi, color: Colors.brown)),
                  ]),
                  const SizedBox(height: 20),

                  // ← FIX: Ringkasan total - ganti grey.shade100 & grey.shade300
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text("Total Keseluruhan",
                            // ← FIX: teks judul terlihat di dark mode
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(label: "Pengguna", value: _totalSiswa + _totalGuru),
                            _MiniStat(label: "Konten", value: _totalMateri + _totalTugas),
                            _MiniStat(label: "Aktivitas", value: _totalSubmisi + _totalAbsensi),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.deepPurple),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      const Expanded(child: Divider()),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value.toString(),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // ← FIX: teks label "Pengguna/Konten/Aktivitas" tidak terlihat di dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Text(value.toString(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      Text(label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey)),
    ]);
  }
}