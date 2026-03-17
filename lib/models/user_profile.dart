class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? className; // menyimpan class_id dari database

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.className,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      id: data['id'] ?? '',
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? 'User',
      role: data['role'] ?? 'student',
      className: data['class_id'], // FIX: pakai class_id bukan class_name
    );
  }
}