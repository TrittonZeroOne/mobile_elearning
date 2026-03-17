import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/user_profile.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  // ── AUTH ────────────────────────────────────────────────────
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile> getProfile(String userId) async {
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserProfile.fromMap(data);
    } catch (e) {
      return UserProfile(
          id: userId, email: '', fullName: 'Error', role: 'student');
    }
  }

  // ── DATA FETCHING ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSubjects(UserProfile user) async {
    if (user.role == 'student') {
      if (user.className == null || user.className!.isEmpty) return [];
      return await client
          .from('subjects')
          .select('*, classes(name), profiles(full_name)')
          .eq('class_id', user.className!)
          .order('name');
    } else if (user.role == 'teacher') {
      return await client
          .from('subjects')
          .select('*, classes(name)')
          .eq('teacher_id', user.id);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMaterials(int subjectId) async {
    return await client
        .from('materials')
        .select()
        .eq('subject_id', subjectId);
  }

  Future<List<Map<String, dynamic>>> getAssignments(int subjectId) async {
    return await client
        .from('assignments')
        .select()
        .eq('subject_id', subjectId);
  }

  // ── TEACHER FEATURES ────────────────────────────────────────

  /// Ambil daftar siswa berdasarkan class_id (primary key tabel classes)
  Future<List<Map<String, dynamic>>> getStudentsForClass(
      String classId) async {
    return await client
        .from('profiles')
        .select()
        .eq('class_id', classId)
        .eq('role', 'student')
        .order('full_name');
  }

  /// Simpan / update absensi (upsert berdasarkan subject_id + student_id + date)
  Future<void> saveAttendance(
      int subjectId, String studentId, String date, String status) async {
    await client.from('attendances').upsert(
      {
        'subject_id': subjectId,
        'student_id': studentId,
        'date': date,
        'status': status,
      },
      onConflict: 'subject_id,student_id,date',
    );
  }

  /// Ambil absensi yang sudah ada untuk subject + tanggal tertentu
  /// Return: List of { student_id, status }
  Future<List<Map<String, dynamic>>> getAttendanceForDate(
      int subjectId, String date) async {
    final data = await client
        .from('attendances')
        .select('student_id, status')
        .eq('subject_id', subjectId)
        .eq('date', date);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Ambil semua riwayat absensi per subject (untuk laporan / export)
  Future<List<Map<String, dynamic>>> getAttendanceHistory(
      int subjectId) async {
    return await client
        .from('attendances')
        .select('*, profiles(full_name)')
        .eq('subject_id', subjectId)
        .order('date', ascending: false)
        .order('profiles(full_name)', ascending: true);
  }

  // ── SUBMISSIONS ─────────────────────────────────────────────

  /// Ambil submissions berdasarkan subject (via assignments)
  Future<List<Map<String, dynamic>>> getSubmissionsBySubject(
      int subjectId) async {
    final assignments = await client
        .from('assignments')
        .select('id')
        .eq('subject_id', subjectId);

    if ((assignments as List).isEmpty) return [];

    final assignmentIds = assignments.map((a) => a['id']).toList();

    return await client
        .from('submissions')
        .select('*, profiles(full_name), assignments(title)')
        .inFilter('assignment_id', assignmentIds);
  }

  Future<List<Map<String, dynamic>>> getSubmissions(
      int assignmentId) async {
    return await client
        .from('submissions')
        .select('*, profiles(full_name)')
        .eq('assignment_id', assignmentId);
  }

  Future<void> gradeSubmission(
      int subId, num grade, String feedback) async {
    await client
        .from('submissions')
        .update({'grade': grade, 'feedback': feedback}).eq('id', subId);
  }

  // ── EXPORT ──────────────────────────────────────────────────
  Future<String> exportAttendance(int subjectId) async {
    final data = await client
        .from('attendances')
        .select('*, profiles(full_name)')
        .eq('subject_id', subjectId)
        .order('date', ascending: true);

    List<List<dynamic>> rows = [
      ['Tanggal', 'Nama Siswa', 'Status']
    ];
    for (var row in data) {
      final studentName = row['profiles'] != null
          ? row['profiles']['full_name']
          : 'Unknown';
      rows.add([row['date'], studentName, row['status']]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<void> exportAttendanceExcel(int subjectId, String subjectName) async {
    final data = await client
        .from('attendances')
        .select('*, profiles(full_name)')
        .eq('subject_id', subjectId)
        .order('date');

    final excel = Excel.createExcel();
    final sheet = excel['Absensi'];

    final headers = ['No', 'Tanggal', 'Nama Siswa', 'Status'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4A148C'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final name = row['profiles']?['full_name'] ?? 'Unknown';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(row['date']?.toString() ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(name);
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1));
      statusCell.value = TextCellValue(row['status']?.toString() ?? '');
      final status = row['status']?.toString() ?? '';
      statusCell.cellStyle = CellStyle(
        fontColorHex: status == 'Hadir'
            ? ExcelColor.fromHexString('#1B5E20')
            : status == 'Sakit'
                ? ExcelColor.fromHexString('#E65100')
                : ExcelColor.fromHexString('#B71C1C'),
      );
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 25);
    sheet.setColumnWidth(3, 12);

    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final safeName = subjectName.replaceAll(RegExp(r'[^\w]'), '_');
    final filename = 'Absensi_' + safeName + '_' + DateTime.now().millisecondsSinceEpoch.toString() + '.xlsx';
    final file = File(dir.path + '/' + filename);
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal encode Excel');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }

  // ── ADMIN FEATURES ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await client.from('profiles').select('*');
  }

  Future<void> createUser(
    String email,
    String password,
    String fullName,
    String role, {
    String? classId,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );
    if (response.user != null && classId != null) {
      await client
          .from('profiles')
          .update({'class_id': classId}).eq('id', response.user!.id);
    }
  }

  // ── CHAT ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getChats(int subjectId) async {
    return await client
        .from('chats')
        .select('*, profiles(full_name)')
        .eq('subject_id', subjectId)
        .order('sent_at', ascending: true);
  }

  Future<void> sendChat(
      int subjectId, String senderId, String message) async {
    await client.from('chats').insert({
      'subject_id': subjectId,
      'sender_id': senderId,
      'message': message,
    });
  }
}