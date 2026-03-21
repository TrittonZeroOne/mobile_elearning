import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/theme_provider.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});
  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final client = Supabase.instance.client;
  bool _loading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await client.from('profiles').select().eq('id', user.id).single();
      if (mounted) setState(() { _profile = data; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal load profil: $e")));
    }
  }

  void _showGantiPassword() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lock, color: Colors.deepPurple), SizedBox(width: 8), Text("Ganti Password"),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: newPassCtrl, obscureText: obscureNew,
              decoration: InputDecoration(
                labelText: 'Password Baru', prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassCtrl, obscureText: obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password', prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Simpan"),
              onPressed: () async {
                if (newPassCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password minimal 6 karakter"))); return;
                }
                if (newPassCtrl.text != confirmPassCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konfirmasi password tidak cocok"))); return;
                }
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  await client.auth.updateUser(UserAttributes(password: newPassCtrl.text));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password berhasil diubah"), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
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

  @override
  Widget build(BuildContext context) {
    if (_profile == null) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  (_profile!['full_name'] as String? ?? 'S').isNotEmpty
                      ? (_profile!['full_name'] as String)[0].toUpperCase() : 'S',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                child: const Text("SISWA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            // Card biodata
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Biodata", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.person, label: "Nama Lengkap", value: _profile!['full_name'] ?? '-'),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.email, label: "Email", value: _profile!['email'] ?? '-'),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.class_, label: "Kelas", value: _profile!['class_id'] ?? '-'),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.badge, label: "Role", value: "Siswa"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ganti Password
            Card(
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8EAF6),
                  child: Icon(Icons.lock, color: Colors.deepPurple),
                ),
                title: const Text("Ganti Password", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Ubah password akun kamu"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showGantiPassword,
              ),
            ),
            const SizedBox(height: 16),

            // Tampilan
            Card(elevation: 2, child: _ThemeToggleTile()),
          ],
        ),
        if (_loading)
          Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

class _ThemeToggleTile extends StatefulWidget {
  @override
  State<_ThemeToggleTile> createState() => _ThemeToggleTileState();
}
class _ThemeToggleTileState extends State<_ThemeToggleTile> {
  final _theme = ThemeProvider();
  @override
  void initState() { super.initState(); _theme.addListener(_rebuild); }
  void _rebuild() => setState(() {});
  @override
  void dispose() { _theme.removeListener(_rebuild); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _theme.isDark ? Colors.indigo.shade900 : Colors.amber.shade100,
        child: Icon(_theme.isDark ? Icons.dark_mode : Icons.light_mode,
            color: _theme.isDark ? Colors.white : Colors.amber.shade700),
      ),
      title: const Text("Tampilan", style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_theme.isDark ? "Mode Gelap aktif" : "Mode Terang aktif"),
      trailing: Switch(value: _theme.isDark, activeColor: Colors.deepPurple, onChanged: (_) => _theme.toggle()),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: Colors.deepPurple),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }
}
