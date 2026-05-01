# Mobile E-Learning 

Aplikasi mobile e-learning berbasis Flutter untuk mendukung kegiatan belajar mengajar di SMA. Aplikasi ini menggunakan Supabase sebagai backend untuk autentikasi, database, realtime chat, notifikasi, dan pengelolaan data pembelajaran.

## Fitur Utama

- Autentikasi pengguna dengan Supabase.
- Hak akses berdasarkan role: `student`, `teacher`, dan `admin`.
- Dashboard berbeda untuk siswa, guru, dan admin.
- Manajemen kelas, mata pelajaran, dan pengguna untuk admin.
- Daftar mata pelajaran dan detail materi/tugas untuk siswa dan guru.
- Absensi siswa oleh guru.
- Export data absensi ke CSV dan Excel.
- Chat dan direct message dengan badge pesan belum dibaca.
- Notifikasi realtime untuk siswa dan guru.
- Profil pengguna.
- Dukungan tema light dan dark.

## Teknologi

- Flutter
- Dart
- Supabase
- Material Design
- Google Fonts
- CSV dan Excel export

## Struktur Folder

```text
lib/
+-- config/
|   +-- supabase_config.dart
+-- models/
|   +-- user_profile.dart
+-- screens/
|   +-- admin/
|   +-- auth/
|   +-- layout/
|   +-- shared/
|   +-- student/
|   +-- teacher/
+-- services/
|   +-- supabase_service.dart
+-- database.sql
+-- full_backup.sql
+-- main.dart
```

## Persyaratan

Pastikan sudah terpasang:

- Flutter SDK versi 3.x
- Dart SDK sesuai versi Flutter
- Android Studio atau VS Code
- Emulator Android, simulator iOS, atau perangkat fisik
- Akun dan project Supabase

## Instalasi

1. Clone atau buka project ini.

2. Install dependency:

   ```bash
   flutter pub get
   ```

3. Siapkan database Supabase.

   Gunakan file SQL yang tersedia:

   - `lib/database.sql`
   - `lib/full_backup.sql`

   Jalankan script yang sesuai melalui Supabase SQL Editor.

4. Konfigurasi Supabase.

   File konfigurasi ada di:

   ```text
   lib/config/supabase_config.dart
   ```

   Sesuaikan `supabaseUrl` dan `supabaseAnonKey` dengan data dari Supabase Dashboard:

   ```text
   Project Settings -> API
   ```

5. Jalankan aplikasi:

   ```bash
   flutter run
   ```

## Perintah Pengembangan

Install dependency:

```bash
flutter pub get
```

Menjalankan aplikasi:

```bash
flutter run
```

Menjalankan test:

```bash
flutter test
```

Menganalisis kode:

```bash
flutter analyze
```

Build APK:

```bash
flutter build apk
```

## Role Pengguna

### Student

- Melihat halaman utama siswa.
- Melihat daftar mata pelajaran.
- Membuka detail materi dan tugas.
- Menggunakan chat.
- Melihat notifikasi.
- Mengelola profil.

### Teacher

- Melihat dashboard guru.
- Mengelola mata pelajaran.
- Melihat detail kelas dan mata pelajaran.
- Mengelola absensi.
- Mengecek submission tugas.
- Export absensi ke Excel.
- Menggunakan chat dan notifikasi.

### Admin

- Melihat dashboard admin.
- Mengelola kelas dan mata pelajaran.
- Mengelola pengguna.
- Mengakses statistik.
- Menggunakan chat.
- Mengelola profil admin.

## Asset

Asset utama aplikasi:

```text
assets/logo.png
```

Logo ini juga digunakan untuk konfigurasi launcher icon pada beberapa platform.

## Catatan

- Aplikasi membutuhkan koneksi ke Supabase agar fitur autentikasi, database, chat, dan notifikasi berjalan.
- Pastikan schema database sudah sesuai dengan query yang digunakan pada service dan screen aplikasi.
- Jangan membagikan key Supabase yang sensitif ke repository publik.
