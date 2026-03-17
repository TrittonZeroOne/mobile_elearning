import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final client = Supabase.instance.client;
  bool _loading = false;

  Future<List<Map<String, dynamic>>> _fetchAnnouncements() async {
    return await client
        .from('announcements')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false);
  }

  void _showFormPengumuman({Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final bodyCtrl = TextEditingController(text: existing?['body'] ?? '');
    String selectedTarget = existing?['target'] ?? 'all';
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit Pengumuman" : "Buat Pengumuman"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Judul
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul Pengumuman',
                    hintText: 'Contoh: Libur Nasional',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Isi
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Isi Pengumuman',
                    hintText: 'Tulis isi pengumuman di sini...',
                    prefixIcon: Icon(Icons.article),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Target penerima
                const Text("Ditujukan kepada:",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text("Semua"),
                      selected: selectedTarget == 'all',
                      selectedColor: Colors.deepPurple.shade100,
                      onSelected: (_) =>
                          setDialogState(() => selectedTarget = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text("Siswa"),
                      selected: selectedTarget == 'student',
                      selectedColor: Colors.blue.shade100,
                      onSelected: (_) =>
                          setDialogState(() => selectedTarget = 'student'),
                    ),
                    ChoiceChip(
                      label: const Text("Guru"),
                      selected: selectedTarget == 'teacher',
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) =>
                          setDialogState(() => selectedTarget = 'teacher'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: Text(isEdit ? "Update" : "Kirim"),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Judul dan isi tidak boleh kosong")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  final senderId = client.auth.currentUser?.id;
                  final data = {
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'target': selectedTarget,
                    'sender_id': senderId,
                  };
                  if (isEdit) {
                    await client
                        .from('announcements')
                        .update(data)
                        .eq('id', existing['id']);
                  } else {
                    await client.from('announcements').insert(data);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit
                            ? "Pengumuman diupdate"
                            : "Pengumuman berhasil dikirim!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal: $e")),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteAnnouncement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Pengumuman"),
        content: const Text("Yakin ingin menghapus pengumuman ini?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await client.from('announcements').delete().eq('id', id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pengumuman dihapus")),
      );
      setState(() {});
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

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengumuman"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Buat Pengumuman",
            onPressed: _showFormPengumuman,
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder(
            future: _fetchAnnouncements(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snapshot.data as List;

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.campaign, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("Belum ada pengumuman"),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showFormPengumuman,
                        icon: const Icon(Icons.add),
                        label: const Text("Buat Pengumuman"),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final a = list[i];
                  final color = _targetColor(a['target']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(Icons.campaign, color: color, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  a['title'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _targetLabel(a['target']),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Isi
                          Text(a['body'] ?? '',
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 10),

                          // Footer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(a['created_at']),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        _showFormPengumuman(existing: a),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        _deleteAnnouncement(a['id'] as int),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFormPengumuman,
        icon: const Icon(Icons.campaign),
        label: const Text("Buat Pengumuman"),
      ),
    );
  }
}