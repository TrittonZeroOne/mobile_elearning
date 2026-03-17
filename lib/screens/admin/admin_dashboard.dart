import 'package:flutter/material.dart';
import 'manage_users_screen.dart';
import 'statistics_screen.dart';
import 'announcements_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Panel Admin",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        _MenuCard(
          icon: Icons.person_add,
          title: "Manajemen Pengguna",
          subtitle: "Kelola akun siswa dan guru",
          color: Colors.deepPurple,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
        ),
        const SizedBox(height: 10),

        _MenuCard(
          icon: Icons.campaign,
          title: "Buat Pengumuman",
          subtitle: "Kirim pengumuman ke siswa atau guru",
          color: Colors.red,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
        ),
        const SizedBox(height: 10),

        _MenuCard(
          icon: Icons.bar_chart,
          title: "Statistik Aplikasi",
          subtitle: "Lihat statistik penggunaan",
          color: Colors.teal,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen())),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}