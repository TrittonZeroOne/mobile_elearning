import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final client = Supabase.instance.client;
  bool _loading = false;
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = _fetchUsers();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    return await client
        .from('profiles')
        .select('*')
        .neq('role', 'admin')
        .order('role')
        .order('full_name');
  }

  Future<List<Map<String, dynamic>>> _fetchKelas() async {
    return await client.from('classes').select().order('id');
  }

  // ============================================================
  // FORM TAMBAH USER
  // ============================================================
  void _showFormTambahUser() async {
    final kelasList = await _fetchKelas();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'student';
    String? selectedKelas;
    bool obscurePassword = true;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Tambah Pengguna"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text("Role: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Siswa"),
                      selected: selectedRole == 'student',
                      selectedColor: Colors.blue.shade100,
                      onSelected: (_) => setDialogState(() => selectedRole = 'student'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Guru"),
                      selected: selectedRole == 'teacher',
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) => setDialogState(() => selectedRole = 'teacher'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedRole == 'student')
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Simpan"),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nama, email, dan password wajib diisi")),
                  );
                  return;
                }
                final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
                if (!emailRegex.hasMatch(emailCtrl.text.trim())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Format email tidak valid")),
                  );
                  return;
                }
                if (selectedRole == 'student' && selectedKelas == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pilih kelas untuk siswa")),
                  );
                  return;
                }
                if (passwordCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password minimal 6 karakter")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  await SupabaseService().createUser(
                    emailCtrl.text.trim(),
                    passwordCtrl.text,
                    nameCtrl.text.trim(),
                    selectedRole,
                    classId: selectedRole == 'student' ? selectedKelas : null,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${selectedRole == 'student' ? 'Siswa' : 'Guru'} berhasil ditambahkan"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _refreshUsers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
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

  // ============================================================
  // FORM EDIT USER
  // ============================================================
  void _showFormEditUser(Map<String, dynamic> user) async {
    final kelasList = await _fetchKelas();
    final nameCtrl = TextEditingController(text: user['full_name'] ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = user['role'] ?? 'student';
    String? selectedKelas = user['class_id'];
    bool obscurePassword = true;
    bool gantiPassword = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Expanded(child: Text("Edit: ${user['full_name'] ?? ''}")),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Role
                Row(
                  children: [
                    const Text("Role: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Siswa"),
                      selected: selectedRole == 'student',
                      selectedColor: Colors.blue.shade100,
                      onSelected: (_) => setDialogState(() => selectedRole = 'student'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Guru"),
                      selected: selectedRole == 'teacher',
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) => setDialogState(() => selectedRole = 'teacher'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nama
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Email (read-only)
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    hintText: user['email'] ?? '',
                  ),
                  controller: TextEditingController(text: user['email'] ?? ''),
                ),
                const SizedBox(height: 12),

                // Kelas (untuk siswa)
                if (selectedRole == 'student')
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
                if (selectedRole == 'student') const SizedBox(height: 12),

                // Toggle ganti password
                Row(
                  children: [
                    Checkbox(
                      value: gantiPassword,
                      onChanged: (val) =>
                          setDialogState(() => gantiPassword = val ?? false),
                    ),
                    const Text("Ganti Password"),
                  ],
                ),

                // Field password (muncul jika toggle aktif)
                if (gantiPassword) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () =>
                            setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Simpan"),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nama tidak boleh kosong")),
                  );
                  return;
                }
                if (gantiPassword && passwordCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password minimal 6 karakter")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  // Update profil
                  final updateData = {
                    'full_name': nameCtrl.text.trim(),
                    'role': selectedRole,
                    'class_id': selectedRole == 'student' ? selectedKelas : null,
                  };
                  await client.from('profiles').update(updateData).eq('id', user['id']);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Data pengguna berhasil diupdate"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _refreshUsers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
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

  // ============================================================
  // HAPUS USER
  // ============================================================
  void _deleteUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Pengguna"),
        content: Text("Yakin hapus '$name'?\nData terkait (absensi, tugas) juga akan terpengaruh."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
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
      await client.from('profiles').delete().eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pengguna berhasil dihapus")),
        );
        _refreshUsers();
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
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'teacher': return Colors.green;
      case 'student': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'teacher': return 'Guru';
      case 'student': return 'Siswa';
      default: return role ?? '-';
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'teacher': return Icons.school;
      case 'student': return Icons.person;
      default: return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Pengguna"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Tambah Pengguna",
            onPressed: _showFormTambahUser,
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data as List;

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("Belum ada pengguna"),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showFormTambahUser,
                        icon: const Icon(Icons.person_add),
                        label: const Text("Tambah Pengguna"),
                      ),
                    ],
                  ),
                );
              }

              final guru = users.where((u) => u['role'] == 'teacher').toList();
              final siswa = users.where((u) => u['role'] == 'student').toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  if (guru.isNotEmpty) ...[
                    _SectionHeader(icon: Icons.school, label: "Guru (${guru.length})", color: Colors.green),
                    const SizedBox(height: 8),
                    ...guru.map((u) => _UserCard(
                          user: u,
                          roleColor: _roleColor(u['role']),
                          roleLabel: _roleLabel(u['role']),
                          roleIcon: _roleIcon(u['role']),
                          onEdit: () => _showFormEditUser(u),
                          onDelete: () => _deleteUser(u['id'], u['full_name'] ?? ''),
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (siswa.isNotEmpty) ...[
                    _SectionHeader(icon: Icons.person, label: "Siswa (${siswa.length})", color: Colors.blue),
                    const SizedBox(height: 8),
                    ...siswa.map((u) => _UserCard(
                          user: u,
                          roleColor: _roleColor(u['role']),
                          roleLabel: _roleLabel(u['role']),
                          roleIcon: _roleIcon(u['role']),
                          onEdit: () => _showFormEditUser(u),
                          onDelete: () => _deleteUser(u['id'], u['full_name'] ?? ''),
                        )),
                  ],
                ],
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
        onPressed: _showFormTambahUser,
        icon: const Icon(Icons.person_add),
        label: const Text("Tambah Pengguna"),
      ),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withOpacity(0.3))),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color roleColor;
  final String roleLabel;
  final IconData roleIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.roleColor,
    required this.roleLabel,
    required this.roleIcon,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.15),
          child: Icon(roleIcon, color: roleColor),
        ),
        title: Text(
          user['full_name'] ?? 'Tanpa Nama',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            if (user['class_id'] != null)
              Text(
                "Kelas: ${user['class_id']}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        isThreeLine: user['class_id'] != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            // Tombol Edit
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: onEdit,
              tooltip: "Edit",
            ),
            // Tombol Hapus
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: onDelete,
              tooltip: "Hapus",
            ),
          ],
        ),
      ),
    );
  }
}