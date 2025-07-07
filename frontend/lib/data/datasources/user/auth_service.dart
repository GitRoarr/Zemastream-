import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../models/user_model.dart';
import '../../../core/config/constants.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  AuthService() {
    _dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  Future<Map<String, dynamic>> register(String fullName, String email, String password, String role) async {
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'role': role,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        throw Exception('Registration failed: ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Dio error during register: ${e.response?.data['message'] ?? e.message}');
      }
      throw Exception('Unexpected error during register: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        throw Exception('Login failed: ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Dio error during login: ${e.response?.data['message'] ?? e.message}');
      }
      throw Exception('Unexpected error during login: $e');
    }
  }

  Future<UserModel> getProfile(String token) async {
    try {
      final response = await _dio.get(
        '/api/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      } else {
        throw Exception('Failed to fetch profile: ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Dio error during getProfile: ${e.response?.data['message'] ?? e.message}');
      }
      throw Exception('Unexpected error during getProfile: $e');
    }
  }

  Future<UserModel> updateProfileImage(
      String token, String userId, Uint8List imageBytes, String fileName) async {
    try {
      if (token.isEmpty) throw Exception('No token provided');

      final formData = FormData();
      if (imageBytes.isNotEmpty) {
        String extension = fileName.split('.').last.toLowerCase();
        String mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        formData.files.add(MapEntry(
          'profileImage',
          MultipartFile.fromBytes(
            imageBytes,
            filename: fileName,
            contentType: MediaType('image', mimeType.split('/').last),
          ),
        ));
      } else {
        throw Exception('No image data provided');
      }

      final response = await _dio.put(
        '/api/users/$userId/profile-image',
        data: formData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        }),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      } else {
        throw Exception('Failed to update profile image: ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Dio error during updateProfileImage: ${e.response?.data['message'] ?? e.message}');
      }
      throw Exception('Unexpected error during updateProfileImage: $e');
    }
  }
}
