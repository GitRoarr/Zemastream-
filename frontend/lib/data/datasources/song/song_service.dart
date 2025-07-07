import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../../../core/config/constants.dart';
import '../../models/song_model.dart';

class SongService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<Map<String, dynamic>> uploadSong({
    required String token,
    required String title,
    required String genre,
    required String description,
    required String artistId,
    required PlatformFile audioFile,
    PlatformFile? coverImage,
  }) async {
    try {
      if (kDebugMode) print('Uploading song: title=$title, genre=$genre, artistId=$artistId');
      _dio.options.headers['Authorization'] = 'Bearer $token';

      MultipartFile audioMultipartFile;
      if (kIsWeb) {
        audioMultipartFile = MultipartFile.fromBytes(
          audioFile.bytes!,
          filename: audioFile.name,
        );
      } else {
        audioMultipartFile = await MultipartFile.fromFile(audioFile.path!, filename: audioFile.name);
      }

      MultipartFile? coverImageMultipartFile;
      if (coverImage != null) {
        if (kIsWeb) {
          coverImageMultipartFile = MultipartFile.fromBytes(
            coverImage.bytes!,
            filename: coverImage.name,
          );
        } else {
          coverImageMultipartFile = await MultipartFile.fromFile(coverImage.path!, filename: coverImage.name);
        }
      }

      final formData = FormData.fromMap({
        'title': title,
        'genre': genre,
        'description': description,
        'artistId': artistId,
        'audio': audioMultipartFile,
        if (coverImageMultipartFile != null) 'coverImage': coverImageMultipartFile,
      });

      final response = await _dio.post('/api/songs/upload', data: formData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Track uploaded successfully'};
      } else if (response.statusCode == 403) {
        throw Exception('Access denied: You must be an artist to upload tracks');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Please log in again');
      } else if (response.statusCode == 404) {
        throw Exception('Upload endpoint not found. Please check if the backend server is running.');
      } else {
        throw Exception('Failed to upload track: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) print('Upload error: $e');
      if (e is DioException && kDebugMode) print('Dio error: ${e.response?.data}');
      throw Exception('Error uploading track: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMySongs(String token) async {
    try {
      if (kDebugMode) print('Fetching my songs with token: $token');
      final response = await _dio.get(
        '/api/songs/my-songs',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> songsJson = response.data as List<dynamic>? ?? [];
        return songsJson.map((item) => item as Map<String, dynamic>).toList();
      } else if (response.statusCode == 403) {
        throw Exception('Access denied: Please check your authentication token or artist role');
      } else {
        throw Exception('Failed to fetch songs: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) print('Fetch songs error: $e');
      if (e is DioException && kDebugMode) print('Dio error: ${e.response?.data}');
      throw Exception('Error fetching songs: $e');
    }
  }

  Future<void> incrementPlayCount(String songId, String token) async {
    try {
      if (kDebugMode) print('Incrementing play count for songId: $songId');
      final response = await _dio.put(
        '/api/songs/$songId/increment-play-count',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to increment play count: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) print('Increment play count error: $e');
      if (e is DioException && kDebugMode) print('Dio error: ${e.response?.data}');
      throw Exception('Error incrementing play count: $e');
    }
  }

  Future<SongModel> fetchSongById(String musicId, String token) async {
    try {
      if (kDebugMode) print('Fetching song by ID: $musicId with token: $token');
      final response = await _dio.get(
        '/songs/$musicId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        return SongModel(
          id: data['_id'],
          title: data['title'] ?? 'Unknown',
          genre: data['genre'] ?? 'Unknown Genre',
          description: data['description'] ?? 'No Description',
          artistId: data['artistId'] ?? '',
          audioPath: data['audioUrl'] ?? data['audioPath'],
          coverImagePath: data['coverImagePath'],
          artist: data['artistName'] ?? 'Unknown Artist',
          duration: data['duration'] != 'N/A' ? data['duration'] : null,
          playCount: data['playCount'] as int? ?? 0,
        );
      } else {
        throw Exception('Failed to fetch song: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) print('Fetch song error: $e');
      if (e is DioException && kDebugMode) print('Dio error: ${e.response?.data}');
      throw Exception('Error fetching song: $e');
    }
  }
  Future<Map<String, dynamic>> updateSongTitle(String token, String songId, String newTitle) async {
    try {
      final response = await _dio.put(
        '/songs/$songId',
        data: {'title': newTitle},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message'] ?? 'Song title updated successfully'};
      } else if (response.statusCode == 404) {
        throw Exception('Song not found or not owned by you. Verify song ID: $songId');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: ${response.data['message'] ?? response.statusMessage}');
      } else {
        throw Exception('Failed to update song: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error updating song: $e');
    }
  }
  Future<void> deleteSong(String token, String songId) async {
    try {
      final response = await _dio.delete(
        '/songs/$songId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => true,
        ),
      );
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Song not found or not owned by you. Verify song ID: $songId');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else {
        throw Exception('Failed to delete song: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error deleting song: $e');
    }
  }
}