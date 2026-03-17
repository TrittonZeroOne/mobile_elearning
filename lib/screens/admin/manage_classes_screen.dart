import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Kelas & Mapel"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.class_), text: "Kelas"),
            Tab(icon: Icon(Icons.book), text: "Mata Pelajaran"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _KelasTab(),
          _MapelTab(),
        ],
      ),
    );
  }
}

// ============================================================
// TAB KELAS
// ============================================================
class _KelasTab extends StatefulWidget {
  const _KelasTab();

  @override
  State<_KelasTab> createState() => _KelasTabState();
}

class _KelasTabState extends State<_KelasTab> {
  final client = Supabase.instance.client;
  bool _loading = false;

  Future<List<Map<String, dynamic>>> _fetchKelas() async {
    return await client.from('classes').select().order('id');
  }

  void _showFormKelas({Map<String, dynamic>? existing}) {
    final idCtrl = TextEditingController(text: existing?['id'] ?? '');
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Edit Kelas" : "Tambah Kelas"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              enabled: !isEdit,
              decoration: const InputDecoration(
                labelText: 'ID Kelas',
                hintText: 'Contoh: XII-IPA-1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Kelas',
                hintText: 'Contoh: XII IPA 1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("ID dan Nama tidak boleh kosong")),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                if (isEdit) {
                  await client
                      .from('classes')
                      .update({'name': nameCtrl.text})
                      .eq('id', idCtrl.text);
                } else {
                  await client.from('classes').insert({
                    'id': idCtrl.text.trim(),
                    'name': nameCtrl.text.trim(),
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isEdit
                            ? "Kelas berhasil diupdate"
                            : "Kelas berhasil ditambahkan")),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: Text(isEdit ? "Update" : "Simpan"),
          ),
        ],
      ),
    );
  }

  void _deleteKelas(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kelas"),
        content: Text("Yakin hapus kelas '$id'? Data mapel terkait juga akan terpengaruh."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await client.from('classes').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kelas berhasil dihapus")),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder(
          future: _fetchKelas(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final kelas = snapshot.data as List;
            if (kelas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.class_, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("Belum ada kelas"),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showFormKelas,
                      icon: const Icon(Icons.add),
                      label: const Text("Tambah Kelas"),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: kelas.length,
              itemBuilder: (ctx, i) {
                final k = kelas[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: const Icon(Icons.class_, color: Colors.deepPurple),
                    ),
                    title: Text(k['name'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showFormKelas(existing: k),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteKelas(k['id']),
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
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab_kelas',
            onPressed: _showFormKelas,
            icon: const Icon(Icons.add),
            label: const Text("Tambah Kelas"),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TAB MATA PELAJARAN
// ============================================================
class _MapelTab extends StatefulWidget {
  const _MapelTab();

  @override
  State<_MapelTab> createState() => _MapelTabState();
}

class _MapelTabState extends State<_MapelTab> {
  final client = Supabase.instance.client;
  bool _loading = false;

  // Daftar hari untuk picker
  static const List<String> _daftarHari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
  ];

  Future<List<Map<String, dynamic>>> _fetchMapel() async {
    return await client
        .from('subjects')
        .select('*, classes(name), profiles(full_name)')
        .order('name');
  }

  Future<List<Map<String, dynamic>>> _fetchKelas() async {
    return await client.from('classes').select().order('id');
  }

  Future<List<Map<String, dynamic>>> _fetchGuru() async {
    return await client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'teacher');
  }

  void _showFormMapel({Map<String, dynamic>? existing}) async {
    final kelasList = await _fetchKelas();
    final guruList = await _fetchGuru();

    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    String? selectedKelas = existing?['class_id'];
    String? selectedGuru = existing?['teacher_id'];
    String? selectedHari = existing?['schedule_day'];
    TimeOfDay? jamMulai;
    TimeOfDay? jamSelesai;
    final isEdit = existing != null;

    // Parse jam existing jika ada (format: "08:00 - 09:30")
    if (existing?['schedule_time'] != null && existing!['schedule_time'] != '') {
      final parts = existing['schedule_time'].toString().split(' - ');
      if (parts.length == 2) {
        final mulai = parts[0].trim().split(':');
        final selesai = parts[1].trim().split(':');
        if (mulai.length == 2) {
          jamMulai = TimeOfDay(
              hour: int.tryParse(mulai[0]) ?? 0,
              minute: int.tryParse(mulai[1]) ?? 0);
        }
        if (selesai.length == 2) {
          jamSelesai = TimeOfDay(
              hour: int.tryParse(selesai[0]) ?? 0,
              minute: int.tryParse(selesai[1]) ?? 0);
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String formatTime(TimeOfDay? t) {
            if (t == null) return '--:--';
            return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          }

          return AlertDialog(
            title: Text(isEdit ? "Edit Mata Pelajaran" : "Tambah Mata Pelajaran"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Mapel
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Mapel',
                      hintText: 'Contoh: Matematika',
                      prefixIcon: Icon(Icons.book),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Kelas
                  DropdownButtonFormField<String>(
                    value: selectedKelas,
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      prefixIcon: Icon(Icons.class_),
                      border: OutlineInputBorder(),
                    ),
                    items: kelasList
                        .map((k) => DropdownMenuItem(
                              value: k['id'] as String,
                              child: Text(k['name'] ?? ''),
                            ))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selectedKelas = val),
                  ),
                  const SizedBox(height: 12),

                  // Guru
                  DropdownButtonFormField<String>(
                    value: selectedGuru,
                    decoration: const InputDecoration(
                      labelText: 'Guru Pengampu',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('-- Pilih Guru --')),
                      ...guruList.map((g) => DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text(g['full_name'] ?? ''),
                          )),
                    ],
                    onChanged: (val) => setDialogState(() => selectedGuru = val),
                  ),
                  const SizedBox(height: 12),

                  // Hari - Picker dengan chips
                  const Text("Hari",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _daftarHari.map((hari) {
                      final isSelected = selectedHari == hari;
                      return ChoiceChip(
                        label: Text(hari,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black87,
                            )),
                        selected: isSelected,
                        selectedColor: Colors.deepPurple,
                        onSelected: (_) =>
                            setDialogState(() => selectedHari = hari),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Jam Mulai & Selesai
                  const Text("Jam Pelajaran",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Jam Mulai
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: jamMulai ?? const TimeOfDay(hour: 7, minute: 0),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => jamMulai = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 18, color: Colors.deepPurple),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Mulai",
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                    Text(
                                      formatTime(jamMulai),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("s/d",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      // Jam Selesai
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: jamSelesai ??
                                  (jamMulai != null
                                      ? TimeOfDay(
                                          hour: jamMulai!.hour + 1,
                                          minute: jamMulai!.minute)
                                      : const TimeOfDay(hour: 8, minute: 0)),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => jamSelesai = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_filled,
                                    size: 18, color: Colors.orange),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Selesai",
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                    Text(
                                      formatTime(jamSelesai),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Preview jadwal
                  if (selectedHari != null || jamMulai != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 6),
                          Text(
                            "${selectedHari ?? '-'}, ${formatTime(jamMulai)} - ${formatTime(jamSelesai)}",
                            style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || selectedKelas == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Nama mapel dan kelas wajib diisi")),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() => _loading = true);

                  // Format jadwal waktu
                  String scheduleTime = '';
                  if (jamMulai != null && jamSelesai != null) {
                    scheduleTime =
                        '${jamMulai!.hour.toString().padLeft(2, '0')}:${jamMulai!.minute.toString().padLeft(2, '0')} - ${jamSelesai!.hour.toString().padLeft(2, '0')}:${jamSelesai!.minute.toString().padLeft(2, '0')}';
                  }

                  try {
                    final data = {
                      'name': nameCtrl.text.trim(),
                      'class_id': selectedKelas,
                      'teacher_id': selectedGuru,
                      'schedule_day': selectedHari ?? '',
                      'schedule_time': scheduleTime,
                    };
                    if (isEdit) {
                      await client
                          .from('subjects')
                          .update(data)
                          .eq('id', existing['id']);
                    } else {
                      await client.from('subjects').insert(data);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEdit
                                ? "Mapel berhasil diupdate"
                                : "Mapel berhasil ditambahkan")),
                      );
                      setState(() {});
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: Text(isEdit ? "Update" : "Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteMapel(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Mata Pelajaran"),
        content: Text("Yakin hapus mapel '$name'?"),
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

    setState(() => _loading = true);
    try {
      await client.from('subjects').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mapel berhasil dihapus")),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder(
          future: _fetchMapel(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final mapel = snapshot.data as List;
            if (mapel.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("Belum ada mata pelajaran"),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showFormMapel,
                      icon: const Icon(Icons.add),
                      label: const Text("Tambah Mapel"),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: mapel.length,
              itemBuilder: (ctx, i) {
                final m = mapel[i];
                final kelasName = m['classes']?['name'] ?? 'Tanpa Kelas';
                final guruName = m['profiles']?['full_name'] ?? 'Belum ada guru';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: const Icon(Icons.book, color: Colors.orange),
                    ),
                    title: Text(m['name'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Kelas: $kelasName"),
                        Text("Guru: $guruName"),
                        if (m['schedule_day'] != null && m['schedule_day'] != '')
                          Row(
                            children: [
                              const Icon(Icons.schedule,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                "${m['schedule_day']} ${m['schedule_time'] ?? ''}",
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showFormMapel(existing: m),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deleteMapel(m['id'] as int, m['name']),
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
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab_mapel',
            onPressed: _showFormMapel,
            icon: const Icon(Icons.add),
            label: const Text("Tambah Mapel"),
          ),
        ),
      ],
    );
  }
}