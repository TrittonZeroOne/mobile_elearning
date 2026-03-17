import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/theme_provider.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final client = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _editing = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final data = await client.from('profiles').select().eq('id', user.id).single();
    setState(() { _profile = data; _nameCtrl.text = data['full_name'] ?? ''; });
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await client.from('profiles').update({'full_name': _nameCtrl.text.trim()}).eq('id', client.auth.currentUser!.id);
      await _loadProfile();
      setState(() => _editing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil berhasil diupdate"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.deepPurple.shade100,
            child: const Icon(Icons.admin_panel_settings, size: 50, color: Colors.deepPurple),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(12)),
            child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Biodata", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(_editing ? Icons.close : Icons.edit, color: Colors.deepPurple),
                      onPressed: () => setState(() => _editing = !_editing),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _editing
                    ? TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      )
                    : _InfoRow(icon: Icons.person, label: "Nama Lengkap", value: _profile!['full_name'] ?? '-'),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.email, label: "Email", value: _profile!['email'] ?? '-'),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.badge, label: "Role", value: "Administrator"),
                if (_editing) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _saveProfile,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text("Simpan Perubahan"),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Tampilan ────────────────────────────────────────
        Card(elevation: 2, child: _ThemeToggleTile()),
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