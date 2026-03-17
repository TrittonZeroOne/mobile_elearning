import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../teacher/class_discussion_screen.dart';

class CourseDetail extends StatelessWidget {
  final int subjectId;
  final String subjectName;
  final String classId;
  const CourseDetail({super.key, required this.subjectId, required this.subjectName, required this.classId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(subjectName),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Materi"),
              Tab(text: "Tugas"),
              Tab(text: "Absensi"),
              Tab(text: "Diskusi"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MaterialTab(subjectId: subjectId),
            _AssignmentTab(subjectId: subjectId),
            const _AttendanceTab(),
            _DiscussionTab(classId: classId),
          ],
        ),
      ),
    );
  }
}

// ── MATERI TAB ────────────────────────────────────────────────
class _MaterialTab extends StatelessWidget {
  final int subjectId;
  const _MaterialTab({required this.subjectId});

  IconData _icon(String? type) {
    switch (type) {
      case 'PDF': return Icons.picture_as_pdf;
      case 'Video': return Icons.video_library;
      case 'Link': return Icons.link;
      case 'Dokumen': return Icons.article;
      default: return Icons.attach_file;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'PDF': return Colors.red;
      case 'Video': return Colors.blue;
      case 'Link': return Colors.teal;
      case 'Dokumen': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SupabaseService().getMaterials(subjectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final materials = snapshot.data as List;
        if (materials.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.folder_open, size: 56, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text("Belum ada materi", style: TextStyle(color: Colors.grey)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: materials.length,
          itemBuilder: (ctx, i) {
            final m = materials[i];
            final type = m['type'] as String?;
            final url = m['content_url'] as String?;
            final color = _color(type);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(_icon(type), color: color),
                ),
                title: Text(m['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (type != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(type, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                    ),
                  if (m['description'] != null && m['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(m['description'],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ]),
                trailing: url != null && url.isNotEmpty
                    ? IconButton(
                        icon: Icon(type == 'Link' ? Icons.open_in_new : Icons.download,
                            color: color),
                        onPressed: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {
                              try { await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {}
                            }
                          }
                        })
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

// ── ASSIGNMENT TAB (SISWA) ────────────────────────────────────
class _AssignmentTab extends StatefulWidget {
  final int subjectId;
  const _AssignmentTab({required this.subjectId});

  @override
  State<_AssignmentTab> createState() => _AssignmentTabState();
}

class _AssignmentTabState extends State<_AssignmentTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('assignments')
          .select('id, title, description, deadline, file_url, submissions(id, student_id, submitted_at, grade, feedback, file_url)')
          .eq('subject_id', widget.subjectId)
          .order('deadline', ascending: true);
      if (mounted) setState(() { _tasks = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _mySubmission(Map<String, dynamic> task) {
    final userId = _client.auth.currentUser?.id ?? '';
    final subs = List<Map<String, dynamic>>.from(task['submissions'] ?? []);
    try {
      return subs.firstWhere((s) => s['student_id'] == userId);
    } catch (_) {
      return null;
    }
  }

  void _showKumpulkan(Map<String, dynamic> task) {
    PlatformFile? file;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.assignment_turned_in, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(child: Text("Kumpulkan: " + (task['title'] ?? ''),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task['description'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
          if (task['deadline'] != null) ...[
            const SizedBox(height: 4),
            Text('Deadline: ' + task['deadline'].toString().split('T')[0],
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
                withData: true,
              );
              if (result == null) return;
              if (result.files.first.size > 10 * 1024 * 1024) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File maks 10MB'), backgroundColor: Colors.red));
                return;
              }
              set(() => file = result.files.first);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: file != null ? Colors.deepPurple : Colors.grey.withOpacity(0.4),
                    width: file != null ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
                color: file != null ? Colors.deepPurple.withOpacity(0.05) : null,
              ),
              child: file == null
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.upload_file, color: Colors.grey.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Text('Pilih file PDF / Word / PPT',
                          style: TextStyle(color: Colors.grey.withOpacity(0.6))),
                    ])
                  : Row(children: [
                      Icon(_fileIcon(file!.extension ?? ''), color: Colors.deepPurple, size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(file!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_fmtSize(file!.size), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ])),
                      IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () => set(() => file = null)),
                    ]),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: (uploading || file == null) ? null : () async {
              set(() => uploading = true);
              try {
                final userId = _client.auth.currentUser!.id;
                final ext = file!.extension ?? 'file';
                final path = 'submissions/' + task['id'].toString() + '/' + userId + '_' +
                    DateTime.now().millisecondsSinceEpoch.toString() + '.' + ext;
                await Supabase.instance.client.storage
                    .from('assignments')
                    .uploadBinary(path, file!.bytes!,
                        fileOptions: FileOptions(contentType: _mimeType(ext)));
                final fileUrl = Supabase.instance.client.storage.from('assignments').getPublicUrl(path);
                await _client.from('submissions').upsert({
                  'assignment_id': task['id'],
                  'student_id': userId,
                  'file_url': fileUrl,
                  'submitted_at': DateTime.now().toIso8601String(),
                }, onConflict: 'assignment_id,student_id');
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tugas berhasil dikumpulkan ✓'),
                        backgroundColor: Colors.green));
              } catch (e) {
                set(() => uploading = false);
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red,
                        duration: const Duration(seconds: 6)));
              }
            },
            icon: uploading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: const Text('Kumpulkan Tugas'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ]),
      )),
    );
  }

  IconData _fileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'ppt': case 'pptx': return Icons.slideshow;
      default: return Icons.attach_file;
    }
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default: return 'application/octet-stream';
    }
  }

  String _fmtSize(int b) {
    if (b < 1024) return b.toString() + ' B';
    if (b < 1024 * 1024) return (b / 1024).toStringAsFixed(1) + ' KB';
    return (b / (1024 * 1024)).toStringAsFixed(1) + ' MB';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    catch (_) { try { await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {} }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tasks.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.withOpacity(0.5)),
        const SizedBox(height: 12),
        const Text("Belum ada tugas", style: TextStyle(color: Colors.grey)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tasks.length,
        itemBuilder: (ctx, i) {
          final task = _tasks[i];
          final sub = _mySubmission(task);
          final deadline = task['deadline'];
          final isOverdue = deadline != null &&
              DateTime.tryParse(deadline.toString())?.isBefore(DateTime.now()) == true;
          final hasLampiran = task['file_url'] != null;
          final statusColor = sub != null ? Colors.green
              : (isOverdue ? Colors.red : Colors.orange);
          final statusLabel = sub != null ? 'Terkumpul'
              : (isOverdue ? 'Terlambat' : 'Belum');

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepPurple.withOpacity(0.12),
                child: const Icon(Icons.assignment, color: Colors.deepPurple, size: 20),
              ),
              title: Text(task['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  if (task['description'] != null && task['description'].toString().isNotEmpty)
                    Text(task['description'],
                        style: TextStyle(fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (deadline != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule, size: 11,
                            color: isOverdue ? Colors.red : Colors.grey),
                        const SizedBox(width: 3),
                        Text(deadline.toString().split('T')[0],
                            style: TextStyle(fontSize: 11,
                                color: isOverdue ? Colors.red
                                    : (isDark ? Colors.white54 : Colors.grey))),
                      ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                    if (sub?['grade'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Nilai: ' + sub!['grade'].toString(),
                            style: const TextStyle(fontSize: 10,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    if (hasLampiran)
                      Icon(Icons.attach_file, size: 12,
                          color: isDark ? Colors.white38 : Colors.grey),
                  ]),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Divider(height: 12),
                    if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                      Text('Instruksi:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.grey)),
                      const SizedBox(height: 4),
                      Text(task['description'],
                          style: TextStyle(fontSize: 13,
                              color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87)),
                      const SizedBox(height: 10),
                    ],
                    if (hasLampiran) ...[
                      GestureDetector(
                        onTap: () => _openUrl(task['file_url']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.attach_file, size: 14, color: Colors.blue),
                            SizedBox(width: 6),
                            Text('Lihat Lampiran Guru',
                                style: TextStyle(fontSize: 12, color: Colors.blue,
                                    decoration: TextDecoration.underline)),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new, size: 12, color: Colors.blue),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (sub != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.check_circle, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Dikumpulkan: ' +
                                (sub['submitted_at']?.toString().split('T')[0] ?? '-'),
                                style: const TextStyle(fontSize: 12, color: Colors.green)),
                            const Spacer(),
                            if (sub['grade'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text('Nilai: ' + sub['grade'].toString(),
                                    style: const TextStyle(fontSize: 12,
                                        color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                          ]),
                          if (sub['feedback'] != null &&
                              sub['feedback'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Feedback: ' + sub['feedback'],
                                style: TextStyle(fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54)),
                          ],
                          if (sub['file_url'] != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _openUrl(sub['file_url']),
                              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                                Icon(Icons.file_present, size: 14, color: Colors.deepPurple),
                                SizedBox(width: 4),
                                Text('Lihat file saya',
                                    style: TextStyle(fontSize: 12, color: Colors.deepPurple,
                                        decoration: TextDecoration.underline)),
                              ]),
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showKumpulkan(task),
                        icon: Icon(sub != null ? Icons.edit : Icons.upload),
                        label: Text(sub != null ? 'Kumpulkan Ulang' : 'Kumpulkan Tugas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sub != null ? Colors.orange : Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── ATTENDANCE TAB ────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const Center(child: Text("User tidak ditemukan"));

    return FutureBuilder(
      future: Supabase.instance.client
          .from('attendances')
          .select()
          .eq('student_id', userId)
          .order('date', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data as List;
        if (records.isEmpty) {
          return const Center(child: Text("Belum ada data kehadiran", style: TextStyle(color: Colors.grey)));
        }
        final total = records.length;
        final hadir = records.where((r) => r['status'] == 'Hadir').length;
        final persen = (hadir / total * 100).toStringAsFixed(1);

        return Column(children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Column(children: [
                Text(hadir.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                const Text("Hadir", style: TextStyle(fontSize: 12, color: Colors.green)),
              ]),
              Column(children: [
                Text(total.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Total", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              Column(children: [
                Text(persen + '%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Text("Persentase", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: records.length,
              itemBuilder: (ctx, i) {
                final r = records[i];
                final status = r['status'] as String? ?? '';
                final color = status == 'Hadir' ? Colors.green : status == 'Sakit' ? Colors.orange : Colors.red;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(
                      status == 'Hadir' ? Icons.check : status == 'Sakit' ? Icons.sick : Icons.close,
                      color: color, size: 16,
                    ),
                  ),
                  title: Text(r['date']?.toString() ?? ''),
                  trailing: Chip(
                    label: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                    backgroundColor: color.withOpacity(0.12),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}


// ── DISCUSSION TAB (wraps ClassDiscussionScreen) ─────────────
class _DiscussionTab extends StatefulWidget {
  final String classId;
  const _DiscussionTab({required this.classId});

  @override
  State<_DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends State<_DiscussionTab> {
  String? _resolvedClassId;

  @override
  void initState() {
    super.initState();
    if (widget.classId.isNotEmpty) {
      _resolvedClassId = widget.classId;
    } else {
      _fetchClassId();
    }
  }

  Future<void> _fetchClassId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('class_id')
          .eq('id', userId)
          .single();
      if (mounted) setState(() => _resolvedClassId = profile['class_id']?.toString() ?? '');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedClassId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_resolvedClassId!.isEmpty) {
      return const Center(child: Text("Kelas tidak ditemukan", style: TextStyle(color: Colors.grey)));
    }
    return ClassDiscussionScreen(
      classId: _resolvedClassId!,
      className: '',
      embedded: true,
    );
  }
}