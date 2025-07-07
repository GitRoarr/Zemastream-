import '../../domain/entities/user.dart';

class UserModel extends User {
  final int followersCount;
  final int followingCount;
  UserModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.role,
    required super.token,
    super.profileImage,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      token: json['token'] ?? '',
      profileImage: json['profileImage'],
      followersCount: int.tryParse(json['followersCount']?.toString() ?? '0') ?? 0,
      followingCount: int.tryParse(json['followingCount']?.toString() ?? '0') ?? 0,

    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'token': token,
      'profileImage': profileImage,
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? token,
    String? profileImage,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}