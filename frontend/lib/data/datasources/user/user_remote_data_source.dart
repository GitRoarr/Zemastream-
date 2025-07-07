import 'dart:typed_data';
import '../../models/user_model.dart';
import 'auth_service.dart';

abstract class UserRemoteDataSource {
  Future<Map<String, dynamic>> register(String fullName, String email, String password, String role);
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> getProfile(String token);
  Future<UserModel> updateProfileImage(String token, String userId, Uint8List imageBytes, String fileName);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final AuthService authService;

  UserRemoteDataSourceImpl({required this.authService});

  @override
  Future<Map<String, dynamic>> register(String fullName, String email, String password, String role) async {
    try {
      final result = await authService.register(fullName, email, password, role);
      return result;
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final result = await authService.login(email, password);
      return result;
    } catch (e) {
      throw Exception('Failed to login user: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final user = await authService.getProfile(token);
      return user.toJson();
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  @override
  Future<UserModel> updateProfileImage(String token, String userId, Uint8List imageBytes, String fileName) async {
    try {
      final user = await authService.updateProfileImage(token, userId, imageBytes, fileName);
      return user;
    } catch (e) {
      throw Exception('Failed to update profile image: $e');
    }
  }
}
