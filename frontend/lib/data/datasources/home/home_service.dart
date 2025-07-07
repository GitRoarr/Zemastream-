import 'package:dio/dio.dart';
import '../../../core/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) {
        return status! < 500; // Allow 404 to proceed and handle it
      },
    ),
  );

  Future<List<Map<String, dynamic>>> fetchReleasedSongs({String? token}) async {
    try {
      final response = await _dio.get(
        '/api/songs',
        options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
      );
      if (response.statusCode == 200) {
        final List<dynamic> songsJson = response.data;
        return songsJson.cast<Map<String, dynamic>>();
      } else {
        print('Fetch songs failed: ${response.statusCode} - ${response.data}');
        return [];
      }
    } catch (e) {
      print('Fetch songs error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSongsByArtist(String artistId, {String? token}) async {
    try {
      print('Fetching songs for artistId: $artistId with token: $token');
      final response = await _dio.get(
        '/api/songs/artist/$artistId',
        options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
      );
      if (response.statusCode == 200) {
        final List<dynamic> songsJson = response.data;
        return songsJson.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        print('No songs found for artistId: $artistId - ${response.data}');
        return [];
      } else {
        print('Fetch songs by artist failed: ${response.statusCode} - ${response.data}');
        return [];
      }
    } catch (e) {
      print('Fetch songs by artist error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchArtistById(String artistId, {String? token}) async {
    try {
      print('Fetching artist with ID: $artistId with token: $token');
      final response = await _dio.get(
        '/api/artists/$artistId',
        options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
      );
      print('Response status: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        final data = response.data['data'] as Map<String, dynamic>? ?? {
          '_id': artistId,
          'fullName': 'Unknown Artist',
          'avatarPath': null,
          'followerCount': 0,
        };
        return data;
      } else {
        print('Fetch artist failed: ${response.statusCode} - ${response.data}');
        return {
          '_id': artistId,
          'fullName': 'Unknown Artist',
          'avatarPath': null,
          'followerCount': 0,
        };
      }
    } catch (e) {
      print('Fetch artist error: $e');
      return {
        '_id': artistId,
        'fullName': 'Unknown Artist',
        'avatarPath': null,
        'followerCount': 0,
      };
    }
  }
  Future<List<Map<String, dynamic>>> fetchArtists({String? token}) async {
    try {
      final response = await _dio.get(
        '/api/artists',
        options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
      );
      if (response.statusCode == 200) {
        final List<dynamic> artistsJson = response.data;
        return artistsJson.cast<Map<String, dynamic>>();
      } else {
        print('Fetch artists failed: ${response.statusCode} - ${response.data}');
        throw Exception('Failed to fetch artists: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      print('Fetch artists error: $e');
      throw Exception('Error fetching artists: $e');
    }
  }
}