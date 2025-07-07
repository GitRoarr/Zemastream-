class User {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String token;
  final String? profileImage;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.token,
    this.profileImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'token': token,
      'profileImage': profileImage,
    };
  }
}