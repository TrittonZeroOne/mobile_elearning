import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import 'class_discussion_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  TeacherCourseDetail — 4 tab: Materi | Tugas | Absensi | Diskusi
// ═══════════════════════════════════════════════════════════════
class TeacherCourseDetail extends StatelessWidget {
  final int    subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final String? scheduleDay;
  final String? scheduleTime;

  const TeacherCourseDetail({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    this.scheduleDay,
    this.scheduleTime,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subjectName),
            Text(className,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          bottom: const TabBar(tabs: [
            Tab(text: 'Materi'),
            Tab(text: 'Tugas'),
            Tab(text: 'Absensi'),
            Tab(text: 'Diskusi'),
          ]),
        ),
        body: TabBarView(children: [
          _MateriTab(subjectId: subjectId),
          _TugasTab(subjectId: subjectId),
          _AbsensiTab(
            subjectId:    subjectId,
            classId:      classId,
            className:    className,
            scheduleDay:  scheduleDay,
            scheduleTime: scheduleTime,
          ),
          ClassDiscussionScreen(
            classId:   classId,
            className: className,
            embedded:  true,
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1 — MATERI
// ═══════════════════════════════════════════════════════════════
class _MateriTab extends StatefulWidget {
  final int subjectId;
  const _MateriTab({required this.subjectId});
  @override State<_MateriTab> createState() => _MateriTabState();
}

class _MateriTabState extends State<_MateriTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;

  static const _types = ['PDF', 'Video', 'Link', 'Dokumen', 'Lainnya'];
  static const _icons = {
    'PDF': Icons.picture_as_pdf, 'Video': Icons.video_library,
    'Link': Icons.link,          'Dokumen': Icons.article,
    'Lainnya': Icons.attach_file,
  };
  static const _colors = {
    'PDF': Colors.red,    'Video': Colors.blue,
    'Link': Colors.teal,  'Dokumen': Colors.indigo,
    'Lainnya': Colors.grey,
  };

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client.from('materials').select()
          .eq('subject_id', widget.subjectId)
          .order('created_at', ascending: false);
      if (mounted) setState(() {
        _materials = List<Map<String, dynamic>>.from(data);
        _loading   = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showTambah() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    final urlCtrl   = TextEditingController();
    String type     = 'PDF';
    PlatformFile? file;
    bool saving     = false;

    bool isFileType(String t) => t == 'PDF' || t == 'Dokumen';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tambah Materi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: const InputDecoration(
                labelText: 'Judul Materi', prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                prefixIcon: Icon(Icons.description), border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(
                  labelText: 'Tipe', border: OutlineInputBorder()),
              items: _types.map((t) =>
                  DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                if (v != null) set(() { type = v; file = null; urlCtrl.clear(); });
              },
            ),
            const SizedBox(height: 12),
            if (!isFileType(type))
              TextField(controller: urlCtrl, decoration: InputDecoration(
                  labelText: type == 'Link' ? 'URL / Link' : 'URL Video',
                  prefixIcon: const Icon(Icons.link),
                  border: const OutlineInputBorder()))
            else ...[
              const Text('File (maks 10MB)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              _FilePicker(
                file: file, color: Colors.purple,
                onPick: () async {
                  final r = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf','doc','docx'],
                      withData: true);
                  if (r == null) return;
                  if (r.files.first.size > 10 * 1024 * 1024) {
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File maks 10MB'),
                            backgroundColor: Colors.red));
                    return;
                  }
                  set(() => file = r.files.first);
                },
                onClear: () => set(() => file = null),
              ),
            ],
            const SizedBox(height: 16),
            _SaveButton(
              saving: saving, label: 'Simpan Materi', color: Colors.purple,
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Judul tidak boleh kosong')));
                  return;
                }
                set(() => saving = true);
                try {
                  String? contentUrl;
                  if (isFileType(type) && file?.bytes != null) {
                    final ext  = file!.extension ?? 'file';
                    final path = 'materials/${widget.subjectId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
                    await _client.storage.from('materials').uploadBinary(
                        path, file!.bytes!, fileOptions: FileOptions(
                            contentType: _mimeFile(ext)));
                    contentUrl = _client.storage.from('materials').getPublicUrl(path);
                  } else if (!isFileType(type) && urlCtrl.text.trim().isNotEmpty) {
                    contentUrl = urlCtrl.text.trim();
                  }
                  await _client.from('materials').insert({
                    'subject_id':  widget.subjectId,
                    'title':       titleCtrl.text.trim(),
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    'type':        type,
                    if (contentUrl != null) 'content_url': contentUrl,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  set(() => saving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal: $e'),
                          backgroundColor: Colors.red));
                }
              },
            ),
          ],
        )),
      )),
    );
  }

  String _mimeFile(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:     return 'application/octet-stream';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    catch (_) { try { await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {} }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await _confirmDialog(context, 'Hapus materi ini?', '');
    if (ok != true) return;
    await _client.from('materials').delete().eq('id', m['id']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _loading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? _EmptyState(icon: Icons.folder_open,
                  text: 'Belum ada materi', hint: 'Tekan + untuk menambah materi')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: _materials.length,
                    itemBuilder: (ctx, i) {
                      final m     = _materials[i];
                      final type  = m['type'] as String? ?? 'Lainnya';
                      final url   = m['content_url'] as String?;
                      final color = _colors[type] ?? Colors.grey;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.15),
                              child: Icon(_icons[type] ?? Icons.attach_file, color: color)),
                          title: Text(m['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(type, style: TextStyle(
                                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                            ),
                            if ((m['description'] as String?)?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(m['description'],
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                          ]),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (url != null && url.isNotEmpty)
                              IconButton(
                                  icon: Icon(
                                      type == 'Link' ? Icons.open_in_new : Icons.download,
                                      color: color, size: 20),
                                  onPressed: () => _openUrl(url)),
                            IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.shade300, size: 20),
                                onPressed: () => _delete(m)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
      Positioned(
        bottom: 16, right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'fab_materi',
          onPressed: _showTambah,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Materi'),
          backgroundColor: Colors.purple,
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 2 — TUGAS
// ═══════════════════════════════════════════════════════════════
class _TugasTab extends StatefulWidget {
  final int subjectId;
  const _TugasTab({required this.subjectId});
  @override State<_TugasTab> createState() => _TugasTabState();
}

class _TugasTabState extends State<_TugasTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('assignments')
          .select('*, submissions(id, student_id, submitted_at, grade, feedback, file_url, profiles(full_name))')
          .eq('subject_id', widget.subjectId);
      if (mounted) setState(() {
        _assignments = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showBuatTugas() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    DateTime? pickedDeadline;
    PlatformFile? lampiran;
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setModal) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Buat Tugas Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(
                  labelText: 'Judul Tugas', prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Deskripsi / Instruksi',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(pickedDeadline == null
                    ? 'Pilih Deadline'
                    : 'Deadline: ${pickedDeadline!.day}/${pickedDeadline!.month}/${pickedDeadline!.year}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModal(() => pickedDeadline = picked);
                },
              ),
              const SizedBox(height: 12),
              const Text('Lampiran (opsional, maks 10MB)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              _FilePicker(
                file: lampiran, color: Colors.orange,
                onPick: () async {
                  final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
                      withData: true);
                  if (result == null) return;
                  if (result.files.first.size > 10 * 1024 * 1024) {
                    if (sheetCtx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File terlalu besar! Maks 10MB'),
                            backgroundColor: Colors.red));
                    return;
                  }
                  setModal(() => lampiran = result.files.first);
                },
                onClear: () => setModal(() => lampiran = null),
              ),
              const SizedBox(height: 16),
              _SaveButton(
                saving: saving, label: 'Simpan Tugas', color: Colors.orange,
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Judul tidak boleh kosong')));
                    return;
                  }
                  setModal(() => saving = true);
                  try {
                    String? fileUrl;
                    if (lampiran != null && lampiran!.bytes != null) {
                      try {
                        final ext  = lampiran!.extension ?? 'file';
                        final ts   = DateTime.now().millisecondsSinceEpoch.toString();
                        final path = 'assignments/${widget.subjectId}/$ts.$ext';
                        await Supabase.instance.client.storage
                            .from('assignments')
                            .uploadBinary(path, lampiran!.bytes!,
                                fileOptions: FileOptions(
                                    contentType: _mimeType(ext), upsert: false));
                        fileUrl = Supabase.instance.client.storage
                            .from('assignments').getPublicUrl(path);
                      } catch (_) {}
                    }
                    final payload = <String, dynamic>{
                      'subject_id':  widget.subjectId,
                      'title':       titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                    };
                    if (pickedDeadline != null)
                      payload['deadline'] = pickedDeadline!.toIso8601String();
                    if (fileUrl != null) payload['file_url'] = fileUrl;
                    await _client.from('assignments').insert(payload);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    _load();
                  } catch (e) {
                    setModal(() => saving = false);
                    if (sheetCtx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 6)));
                  }
                },
              ),
            ],
          )),
        ),
      ),
    );
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':  return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:     return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _loading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? _EmptyState(icon: Icons.assignment_outlined,
                  text: 'Belum ada tugas', hint: 'Tekan + untuk membuat tugas baru')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _assignments.length,
                    itemBuilder: (ctx, i) => _AssignmentCard(
                        assignment: _assignments[i], onRefresh: _load),
                  ),
                ),
      Positioned(
        bottom: 16, right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'fab_tugas',
          onPressed: _showBuatTugas,
          icon: const Icon(Icons.add),
          label: const Text('Buat Tugas'),
          backgroundColor: Colors.orange,
        ),
      ),
    ]);
  }
}

// ── Assignment Card ───────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onRefresh;
  const _AssignmentCard({required this.assignment, required this.onRefresh});

  List<Map<String, dynamic>> get _subs =>
      List<Map<String, dynamic>>.from(assignment['submissions'] ?? []);

  String _fmt(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return '-'; }
  }

  Color _gradeColor(dynamic g) {
    if (g == null) return Colors.grey;
    final v = (g as num).toDouble();
    if (v >= 80) return Colors.green;
    if (v >= 60) return Colors.orange;
    return Colors.red;
  }

  void _showNilai(BuildContext context, Map<String, dynamic> sub) {
    final gradeCtrl = TextEditingController(text: sub['grade']?.toString() ?? '');
    final feedCtrl  = TextEditingController(text: sub['feedback'] ?? '');
    final client    = Supabase.instance.client;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Nilai — ${sub['profiles']?['full_name'] ?? ''}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: gradeCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Nilai (0–100)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: feedCtrl, maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Feedback', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () async {
            final g = num.tryParse(gradeCtrl.text);
            if (g == null) return;
            await client.from('submissions')
                .update({'grade': g, 'feedback': feedCtrl.text.trim()})
                .eq('id', sub['id']);
            if (ctx.mounted) Navigator.pop(ctx);
            onRefresh();
          },
          child: const Text('Simpan')),
      ],
    ));
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    catch (_) { try { await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {} }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final deadline  = assignment['deadline'];
    final isOverdue = deadline != null &&
        DateTime.tryParse(deadline.toString())?.isBefore(DateTime.now()) == true;
    final client    = Supabase.instance.client;
    final hasFile   = assignment['file_url'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
            backgroundColor: Colors.orange.withOpacity(0.15),
            child: const Icon(Icons.assignment, color: Colors.orange)),
        title: Text(assignment['title'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (assignment['description'] != null &&
              assignment['description'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(assignment['description'],
                  style: TextStyle(fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          Wrap(spacing: 6, runSpacing: 2, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today, size: 12,
                  color: isOverdue ? Colors.red : (isDark ? Colors.white54 : Colors.grey)),
              const SizedBox(width: 4),
              Text(
                deadline != null ? 'Deadline: ${_fmt(deadline)}' : 'Tanpa deadline',
                style: TextStyle(fontSize: 11,
                    color: isOverdue ? Colors.red : (isDark ? Colors.white54 : Colors.grey)),
              ),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${_subs.length} terkumpul',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
            ),
            if (hasFile)
              Icon(Icons.attach_file, size: 13,
                  color: isDark ? Colors.white54 : Colors.grey),
          ]),
        ]),
        children: [
          if (hasFile) ...[
            GestureDetector(
              onTap: () => _openUrl(context, assignment['file_url']?.toString() ?? ''),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.attach_file, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(child: Text('Lihat lampiran tugas (file guru)',
                      style: TextStyle(fontSize: 12, color: Colors.orange,
                          decoration: TextDecoration.underline))),
                  Icon(Icons.open_in_new, size: 13, color: Colors.orange),
                ]),
              ),
            ),
            const Divider(height: 8),
          ],
          if (_subs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.inbox_outlined, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text('Belum ada yang mengumpulkan',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
              ]),
            )
          else
            ..._subs.map((sub) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _gradeColor(sub['grade']).withOpacity(0.15),
                  child: Text(sub['grade']?.toString() ?? '?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: _gradeColor(sub['grade']))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub['profiles']?['full_name'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('Dikumpulkan: ${_fmt(sub['submitted_at'])}',
                        style: TextStyle(fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey)),
                    if (sub['file_url'] != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _openUrl(context, sub['file_url']?.toString() ?? ''),
                        child: const Row(children: [
                          Icon(Icons.attach_file, size: 12, color: Colors.blue),
                          SizedBox(width: 4),
                          Text('Lihat file tugas siswa',
                              style: TextStyle(fontSize: 11, color: Colors.blue,
                                  decoration: TextDecoration.underline)),
                        ]),
                      ),
                    ] else ...[
                      const Text('Belum ada file',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                )),
                IconButton(
                  icon: Icon(Icons.grade, color: _gradeColor(sub['grade'])),
                  tooltip: 'Beri Nilai',
                  onPressed: () => _showNilai(context, sub),
                ),
              ]),
            )),
          const Divider(height: 1),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
            label: const Text('Hapus Tugas',
                style: TextStyle(color: Colors.red, fontSize: 12)),
            onPressed: () async {
              final ok = await _confirmDialog(
                  context, 'Hapus Tugas?',
                  'Semua pengumpulan terkait akan ikut terhapus.');
              if (ok == true) {
                await client.from('assignments').delete().eq('id', assignment['id']);
                onRefresh();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 3 — ABSENSI
// ═══════════════════════════════════════════════════════════════
class _AbsensiTab extends StatefulWidget {
  final int     subjectId;
  final String  classId;
  final String  className;
  final String? scheduleDay;
  final String? scheduleTime;

  const _AbsensiTab({
    required this.subjectId, required this.classId,
    required this.className, this.scheduleDay, this.scheduleTime,
  });
  @override State<_AbsensiTab> createState() => _AbsensiTabState();
}

class _AbsensiTabState extends State<_AbsensiTab> {
  final _service = SupabaseService();
  final Map<String, String> _status = {};
  DateTime _date = DateTime.now();
  bool _loadingStudents = true;
  bool _loadingExisting = false;
  bool _saving          = false;
  bool _exporting       = false;
  List<Map<String, dynamic>> _students = [];

  static const _hariMap = {
    1:'Senin', 2:'Selasa', 3:'Rabu', 4:'Kamis', 5:'Jumat', 6:'Sabtu', 7:'Minggu'
  };

  String get _hari    => _hariMap[_date.weekday] ?? '';
  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}';
  String get _display => '${_date.day}/${_date.month}/${_date.year}';
  bool get _isDayMatch =>
      widget.scheduleDay == null || widget.scheduleDay!.isEmpty ||
      _hari == widget.scheduleDay;

  @override void initState() { super.initState(); _loadStudents(); }

  Future<void> _loadStudents() async {
    setState(() => _loadingStudents = true);
    try {
      final students = await _service.getStudentsForClass(widget.classId);
      if (mounted) {
        setState(() {
          _students        = List<Map<String, dynamic>>.from(students);
          _loadingStudents = false;
          for (final s in _students) _status[s['id'] as String] = 'Hadir';
        });
      }
      await _loadExisting();
    } catch (_) { if (mounted) setState(() => _loadingStudents = false); }
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final data = await _service.getAttendanceForDate(widget.subjectId, _dateStr);
      if (mounted) {
        for (final s in _students) _status[s['id'] as String] = 'Hadir';
        for (final a in data) {
          final sid = a['student_id'] as String?;
          final st  = a['status']     as String?;
          if (sid != null && st != null) _status[sid] = st;
        }
        setState(() => _loadingExisting = false);
      }
    } catch (_) { if (mounted) setState(() => _loadingExisting = false); }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now(),
    );
    if (p != null && mounted) {
      setState(() { _date = p; _loadingExisting = true; });
      await _loadExisting();
    }
  }

  Future<void> _save() async {
    if (!_isDayMatch) {
      showDialog(context: context, builder: (c) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8),
          Text('Peringatan'),
        ]),
        content: Text('Tanggal ($_hari) bukan hari jadwal ${widget.scheduleDay}.'),
        actions: [ElevatedButton(
            onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await Future.wait(_status.entries.map((e) =>
          _service.saveAttendance(widget.subjectId, e.key, _dateStr, e.value)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Absensi $_display berhasil disimpan ✓'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _service.exportAttendanceExcel(widget.subjectId, widget.className);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File Excel berhasil disimpan ✓'),
              backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: $e')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Hadir': return Colors.green;
      case 'Sakit': return Colors.blue;
      case 'Izin':  return Colors.orange;
      case 'Alfa':  return Colors.red;
      default:      return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Hadir': return Icons.check_circle;
      case 'Sakit': return Icons.local_hospital;
      case 'Izin':  return Icons.mail;
      case 'Alfa':  return Icons.cancel;
      default:      return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _date.year  == DateTime.now().year &&
                    _date.month == DateTime.now().month &&
                    _date.day   == DateTime.now().day;
    int hadir = 0, sakit = 0, izin = 0, alfa = 0;
    for (final v in _status.values) {
      if (v == 'Hadir') hadir++;
      else if (v == 'Sakit') sakit++;
      else if (v == 'Izin') izin++;
      else alfa++;
    }

    return Stack(children: [
      _loadingStudents
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text('Tidak ada siswa di kelas ini'))
              : Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Theme.of(context).cardColor,
                    child: Row(children: [
                      const Icon(Icons.event, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isToday ? 'Hari Ini – $_hari, $_display' : '$_hari, $_display',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (!_isDayMatch)
                          Text('Jadwal hari ${widget.scheduleDay}',
                              style: const TextStyle(fontSize: 11, color: Colors.orange)),
                      ])),
                      IconButton(
                        icon: _exporting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.file_download, color: Colors.blue),
                        tooltip: 'Export Excel',
                        onPressed: _exporting ? null : _export,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: const Text('Ganti'),
                        onPressed: _pickDate,
                      ),
                    ]),
                  ),
                  if (!_loadingExisting)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(children: [
                        _Chip('Hadir', hadir, Colors.green),
                        const SizedBox(width: 6),
                        _Chip('Sakit', sakit, Colors.blue),
                        const SizedBox(width: 6),
                        _Chip('Izin',  izin,  Colors.orange),
                        const SizedBox(width: 6),
                        _Chip('Alfa',  alfa,  Colors.red),
                      ]),
                    ),
                  if (_loadingExisting)
                    const Padding(padding: EdgeInsets.all(4),
                        child: LinearProgressIndicator()),
                  Expanded(child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: _students.length,
                    itemBuilder: (ctx, i) {
                      final s   = _students[i];
                      final sid = s['id'] as String;
                      final cur = _status[sid] ?? 'Hadir';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(children: [
                            Text('${i+1}.',
                                style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _statusColor(cur).withOpacity(0.15),
                              child: Icon(_statusIcon(cur), size: 18,
                                  color: _statusColor(cur)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s['full_name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14))),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(cur).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _statusColor(cur).withOpacity(0.4)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: cur, isDense: true,
                                  style: TextStyle(color: _statusColor(cur),
                                      fontWeight: FontWeight.bold, fontSize: 13),
                                  icon: Icon(Icons.expand_more, size: 16,
                                      color: _statusColor(cur)),
                                  items: ['Hadir','Sakit','Izin','Alfa']
                                      .map((v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v, style: TextStyle(
                                            color: _statusColor(v),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                      )).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _status[sid] = v);
                                  },
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  )),
                ]),
      if (_students.isNotEmpty)
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Center(
            child: FloatingActionButton.extended(
              heroTag: 'fab_absensi',
              onPressed: _saving ? null : _save,
              backgroundColor: _isDayMatch ? Colors.green : Colors.orange,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan Absensi',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  final String label; final int count; final Color color;
  const _Chip(this.label, this.count, this.color);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text('$count', style: TextStyle(fontWeight: FontWeight.bold,
          color: color, fontSize: 16)),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ]),
  ));
}

class _FilePicker extends StatelessWidget {
  final PlatformFile? file;
  final Color color;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _FilePicker({required this.file, required this.color,
      required this.onPick, required this.onClear});

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024*1024) return '${(b/1024).toStringAsFixed(1)} KB';
    return '${(b/(1024*1024)).toStringAsFixed(1)} MB';
  }

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onPick,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
            color: file != null ? color : Colors.grey.shade400,
            width: file != null ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
        color: file != null ? color.withOpacity(0.05) : null,
      ),
      child: file == null
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.upload_file, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text('Pilih file', style: TextStyle(color: Colors.grey.shade500)),
            ])
          : Row(children: [
              Icon(Icons.attach_file, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(_fmtSize(file!.size),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 18,
                  color: Colors.red), onPressed: onClear),
            ]),
    ),
  );
}

class _SaveButton extends StatelessWidget {
  final bool saving; final String label;
  final Color color; final VoidCallback? onPressed;
  const _SaveButton({required this.saving, required this.label,
      required this.color, this.onPressed});
  @override Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save),
      label: Text(label),
      style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String text; final String hint;
  const _EmptyState({required this.icon, required this.text, required this.hint});
  @override Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 16)),
      const SizedBox(height: 4),
      Text(hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
    ],
  ));
}

Future<bool?> _confirmDialog(BuildContext ctx, String title, String body) =>
    showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title),
      content: body.isNotEmpty ? Text(body) : null,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal')),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Hapus', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));