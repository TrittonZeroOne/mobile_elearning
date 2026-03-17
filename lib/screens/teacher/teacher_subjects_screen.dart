import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';
import 'teacher_course_detail.dart';

// Simpel seperti StudentSubjectsScreen:
// tap mapel → buka TeacherCourseDetail (4 tab)
class TeacherSubjectsScreen extends StatefulWidget {
  const TeacherSubjectsScreen({super.key});
  @override State<TeacherSubjectsScreen> createState() =>
      _TeacherSubjectsScreenState();
}

class _TeacherSubjectsScreenState extends State<TeacherSubjectsScreen> {
  static const _hariOrder = {
    'Senin':1, 'Selasa':2, 'Rabu':3, 'Kamis':4, 'Jumat':5, 'Sabtu':6,
  };
  static const _hariMap = {
    1:'Senin', 2:'Selasa', 3:'Rabu', 4:'Kamis', 5:'Jumat', 6:'Sabtu',
  };

  List<String> _hariList = [];
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  bool    _loading     = true;
  String? _selectedHari;

  @override void initState() { super.initState(); _loadSubjects(); }

  Future<void> _loadSubjects() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final subjects = await SupabaseService().getSubjects(
        UserProfile(id: user.id, email: '', fullName: '', role: 'teacher'),
      );

      subjects.sort((a, b) =>
          (_hariOrder[a['schedule_day']] ?? 99)
              .compareTo(_hariOrder[b['schedule_day']] ?? 99));

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final s in subjects) {
        final hari = s['schedule_day'] as String? ?? 'Lainnya';
        grouped.putIfAbsent(hari, () => []).add(s);
      }

      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) =>
            (_hariOrder[a] ?? 99).compareTo(_hariOrder[b] ?? 99));

      final hariIni    = _hariMap[DateTime.now().weekday];
      final defaultHari = sortedKeys.contains(hariIni)
          ? hariIni! : sortedKeys.isNotEmpty ? sortedKeys.first : '';

      if (mounted) setState(() {
        _grouped      = grouped;
        _hariList     = sortedKeys;
        _selectedHari = defaultHari;
        _loading      = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  bool _isHariIni(String hari) => _hariMap[DateTime.now().weekday] == hari;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hariList.isEmpty) return const Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.book_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('Belum ada mata pelajaran yang diajarkan'),
      ],
    ));

    final subjects = _grouped[_selectedHari] ?? [];

    return Column(children: [
      // ── Pill Tab Hari ──────────────────────────────────────
      Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _hariList.map((hari) {
            final isSelected = hari == _selectedHari;
            final isToday    = _isHariIni(hari);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedHari = hari),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.green.withOpacity(0.25)
                            : Colors.green.shade50),
                    borderRadius: BorderRadius.circular(24),
                    border: isToday && !isSelected
                        ? Border.all(color: Colors.green, width: 1.5) : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(hari, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.green,
                      fontWeight: FontWeight.w600, fontSize: 13,
                    )),
                    if (isToday) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          }).toList()),
        ),
      ),
      const Divider(height: 1),

      // ── List Mapel — tap → TeacherCourseDetail ─────────────
      Expanded(child: RefreshIndicator(
        onRefresh: _loadSubjects,
        child: subjects.isEmpty
            ? const Center(child: Text('Tidak ada mapel hari ini'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subjects.length,
                itemBuilder: (ctx, i) {
                  final sub          = subjects[i];
                  final subjectName  = sub['name']              as String? ?? '';
                  final kelasName    = sub['classes']?['name']  as String? ?? 'Tanpa Kelas';
                  final classId      = sub['class_id']?.toString() ?? '';
                  final scheduleDay  = sub['schedule_day']      as String?;
                  final scheduleTime = sub['schedule_time']     as String?;
                  final subjectId    = sub['id']                as int;
                  final isDark       = Theme.of(ctx).brightness == Brightness.dark;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.15),
                        child: const Icon(Icons.book,
                            color: Colors.green, size: 20)),
                      title: Text(subjectName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Icon(Icons.class_, size: 12,
                              color: isDark ? Colors.white54 : Colors.grey),
                          const SizedBox(width: 4),
                          Text(kelasName,
                              style: const TextStyle(fontSize: 12)),
                        ]),
                        if (scheduleTime != null && scheduleTime.isNotEmpty)
                          Row(children: [
                            Icon(Icons.access_time, size: 12,
                                color: isDark ? Colors.white54 : Colors.grey),
                            const SizedBox(width: 4),
                            Text(scheduleTime,
                                style: const TextStyle(fontSize: 12)),
                          ]),
                      ]),
                      isThreeLine: scheduleTime != null &&
                          scheduleTime.isNotEmpty,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(ctx,
                        MaterialPageRoute(builder: (_) => TeacherCourseDetail(
                          subjectId:    subjectId,
                          subjectName:  subjectName,
                          classId:      classId,
                          className:    kelasName,
                          scheduleDay:  scheduleDay,
                          scheduleTime: scheduleTime,
                        )),
                      ),
                    ),
                  );
                },
              ),
      )),
    ]);
  }
}