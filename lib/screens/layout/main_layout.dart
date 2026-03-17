import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../student/student_home_screen.dart';
import '../student/student_subjects_screen.dart';
import '../student/student_chat_screen.dart';
import '../student/student_profile_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../teacher/teacher_subjects_screen.dart';
import '../teacher/teacher_chat_screen.dart';
import '../teacher/teacher_profile_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/manage_classes_screen.dart';
import '../admin/admin_chat_screen.dart';
import '../admin/admin_profile_screen.dart';
import '../shared/theme_provider.dart';
import '../shared/notification_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final _client  = Supabase.instance.client;
  final _service = SupabaseService();
  final _theme   = ThemeProvider();

  UserProfile? _currentUser;
  int  _currentIndex = 0;
  int  _totalUnread  = 0;
  int  _totalNotif   = 0;
  RealtimeChannel? _unreadChannel;
  RealtimeChannel? _notifChannel;
  Timer? _pollTimer; // polling fallback agar badge pasti muncul
  List<Widget>? _screens;
  late final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _theme.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _unreadChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    _pollTimer?.cancel();
    _theme.removeListener(_onThemeChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final profile = await _service.getProfile(user.id);
    if (!mounted) return;
    setState(() {
      _currentUser = profile;
      _screens     = null;
    });
    await Future.wait([_refreshUnread(), _refreshNotif()]);
    _startListeners();
    _startPolling(); // polling setiap 15 detik sebagai fallback
  }

  // ── Realtime listeners ─────────────────────────────────────
  void _startListeners() {
    final myId = _client.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;
    _unreadChannel?.unsubscribe();
    _notifChannel?.unsubscribe();

    // Chat unread listener
    _unreadChannel = _client
        .channel('unread_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert, schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id', value: myId),
          callback: (_) => _refreshUnread(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update, schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id', value: myId),
          callback: (_) => _refreshUnread(),
        )
        .subscribe();

    // Notif realtime — tanpa filter agar pasti terpanggil,
    // lalu filter di callback (lebih reliable untuk UUID)
    _notifChannel = _client
        .channel('notif_all_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            // Cek apakah notif ini milik user ini
            final row = payload.newRecord;
            if (row['user_id'] == myId) _refreshNotif();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['user_id'] == myId) _refreshNotif();
          },
        )
        .subscribe();
  }

  // ── Polling fallback setiap 15 detik ──────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _refreshNotif();
    });
  }

  // ── Refresh helpers ────────────────────────────────────────
  Future<void> _refreshUnread() async {
    final myId = _client.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;
    try {
      final data = await _client
          .from('direct_messages')
          .select('id')
          .eq('receiver_id', myId)
          .eq('is_read', false);
      if (mounted) setState(() => _totalUnread = (data as List).length);
    } catch (_) {}
  }

  Future<void> _refreshNotif() async {
    final myId = _client.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;
    try {
      final data = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', myId)
          .eq('is_read', false);
      if (mounted) setState(() => _totalNotif = (data as List).length);
    } catch (_) {}
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
    _refreshNotif();
  }

  // ── Screens ────────────────────────────────────────────────
  List<Widget> _buildScreens() {
    if (_currentUser == null)
      return [const Center(child: CircularProgressIndicator())];
    switch (_currentUser!.role) {
      case 'student':
        return [
          const StudentHomeScreen(),
          const StudentSubjectsScreen(),
          StudentChatScreen(onUnreadChanged: _refreshUnread),
          const StudentProfileScreen(),
        ];
      case 'teacher':
        return [
          TeacherDashboard(),
          TeacherSubjectsScreen(),
          TeacherChatScreen(onUnreadChanged: _refreshUnread),
          const TeacherProfileScreen(),
        ];
      case 'admin':
        return [
          const AdminDashboard(),
          const ManageClassesScreen(),
          AdminChatScreen(onUnreadChanged: _refreshUnread),
          const AdminProfileScreen(),
        ];
      default:
        return [const LoginScreen()];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    final chatIcon = _totalUnread > 0
        ? Badge(
            label: Text(_totalUnread > 99 ? '99+' : '$_totalUnread',
                style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.red,
            child: const Icon(Icons.chat))
        : const Icon(Icons.chat);

    switch (_currentUser?.role) {
      case 'admin':
        return [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.school),    label: 'Kelas & Mapel'),
          BottomNavigationBarItem(icon: chatIcon,                    label: 'Chat'),
          const BottomNavigationBarItem(icon: Icon(Icons.person),    label: 'Profil'),
        ];
      case 'teacher':
        return [
          const BottomNavigationBarItem(icon: Icon(Icons.home),  label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.book),  label: 'Mapel'),
          BottomNavigationBarItem(icon: chatIcon,                 label: 'Chat'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      default:
        return [
          const BottomNavigationBarItem(icon: Icon(Icons.home),  label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.book),  label: 'Mapel'),
          BottomNavigationBarItem(icon: chatIcon,                 label: 'Chat'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
    }
  }

  String _getTitle() {
    switch (_currentUser?.role) {
      case 'student': return 'E-Learning - STUDENT';
      case 'teacher': return 'E-Learning - GURU';
      case 'admin':   return 'E-Learning - ADMIN';
      default:        return 'E-Learning';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = _screens ??= _buildScreens();
    final isAdmin = _currentUser!.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          // ── Notif bell: SELALU tampil untuk guru & siswa ──
          if (!isAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Notifikasi',
                  onPressed: _openNotifications,
                  icon: Icon(
                    _totalNotif > 0
                        ? Icons.notifications
                        : Icons.notifications_none,
                  ),
                ),
                if (_totalNotif > 0)
                  Positioned(
                    top: 6,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                          minWidth: 18, minHeight: 18),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _totalNotif > 99 ? '99+' : '$_totalNotif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),

          // ── Logout ────────────────────────────────────────
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _pollTimer?.cancel();
              _unreadChannel?.unsubscribe();
              _notifChannel?.unsubscribe();
              await _client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          if (i == 2) _refreshUnread();
        },
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          _pageController.animateToPage(i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
          if (i == 2) _refreshUnread();
        },
        type: BottomNavigationBarType.fixed,
        items: _getNavItems(),
      ),
    );
  }
}