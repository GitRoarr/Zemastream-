import 'package:dio/dio.dart';
import '../../../core/config/constants.dart';

class AdminService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  Future<List<Map<String, dynamic>>> fetchAllUsers(String token) async {
    try {
      final response = await _dio.get(
        '/api/admin/users',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('Fetch users error: $e');
      throw Exception('Error fetching users: $e');
    }
  }

  Future<void> createUser(String token, String fullName, String email, String role, String password) async {
    try {
      await _dio.post(
        '/api/admin/users',
        data: {
          'fullName': fullName,
          'email': email,
          'role': role,
          'password': password,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Create user error: $e');
      throw Exception('Error creating user: $e');
    }
  }

  Future<void> updateUser(String token, String userId, String fullName, String email, String role) async {
    try {
      await _dio.put(
        '/api/admin/users/$userId',
        data: {
          'fullName': fullName,
          'email': email,
          'role': role,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Update user error: $e');
      throw Exception('Error updating user: $e');
    }
  }

  Future<void> deleteUser(String token, String userId) async {
    try {
      await _dio.delete(
        '/api/admin/users/$userId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Delete user error: $e');
      throw Exception('Error deleting user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllSongs(String token) async {
    try {
      final response = await _dio.get(
        '/api/admin/songs',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      final data = List<Map<String, dynamic>>.from(response.data);
      print('Fetched songs data: $data');
      return data;
    } catch (e) {
      print('Fetch songs error: $e');
      throw Exception('Error fetching songs: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedSongs(String token) async {
    try {
      final response = await _dio.get(
        '/api/songs/featured',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('Fetch featured songs error: $e');
      throw Exception('Error fetching featured songs: $e');
    }
  }

  Future<void> pinFeaturedSong(String token, String songId, int featuredOrder) async {
    try {
      await _dio.put(
        '/api/songs/pin-featured/$songId',
        data: {
          'featuredOrder': featuredOrder,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Pin featured song error: $e');
      throw Exception('Error pinning song: $e');
    }
  }

  Future<void> unpinFeaturedSong(String token, String songId) async {
    try {
      await _dio.put(
        '/api/songs/unpin-featured/$songId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Unpin featured song error: $e');
      throw Exception('Error unpinning song: $e');
    }
  }

  Future<void> createSong(String token, String title, String genre, String description, String artistId, String audioPath, String coverImagePath) async {
    try {
      await _dio.post(
        '/api/admin/songs',
        data: {
          'title': title,
          'genre': genre,
          'description': description,
          'artistId': artistId,
          'audioPath': audioPath,
          'coverImagePath': coverImagePath,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Create song error: $e');
      throw Exception('Error creating song: $e');
    }
  }

  Future<void> updateSong(String token, String songId, String title, String genre) async {
    try {
      await _dio.put(
        '/api/admin/songs/$songId',
        data: {
          'title': title,
          'genre': genre,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Update song error: $e');
      throw Exception('Error updating song: $e');
    }
  }

  Future<void> deleteSong(String token, String songId) async {
    try {
      await _dio.delete(
        '/api/admin/songs/$songId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      print('Delete song error: $e');
      throw Exception('Error deleting song: $e');
    }
  }

  Future<int> fetchTotalListeners(String token) async {
    try {
      final response = await _dio.get(
        '/api/admin/listeners',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      return response.data['totalListeners'] as int;
    } catch (e) {
      print('Fetch listeners error: $e');
      throw Exception('Error fetching listeners: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllArtists(String token) async {
    try {
      final response = await _dio.get(
        '/api/admin/artists',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('Fetch artists error: $e');
      throw Exception('Error fetching artists: $e');
    }
  }
}