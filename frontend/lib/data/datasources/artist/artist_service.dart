import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../core/config/constants.dart';

class ArtistService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<String> fetchArtistName(String artistId, String token) async {
    try {
      if (kDebugMode) print('Fetching artist name for artistId: $artistId');
      final response = await _dio.get(
        '/api/artists/$artistId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        final artistData = response.data as Map<String, dynamic>;
        return artistData['fullName']?.toString() ?? 'Unknown Artist';
      } else if (response.statusCode == 404) {
        if (kDebugMode) print('Artist not found for ID: $artistId');
        return 'Unknown Artist';
      } else {
        throw Exception('Failed to fetch artist: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) print('Fetch artist error: $e');
      return 'Unknown Artist'; // Fallback
    }
  }

  Future<List<Map<String, dynamic>>> fetchArtists({String query = '', String token = ''}) async {
    try {
      if (kDebugMode) print('Fetching artists with query: $query');
      final response = await _dio.get(
        '/api/artists',
        queryParameters: query.isNotEmpty ? {'query': query} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        final artistsData = response.data as List<dynamic>;
        return artistsData.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        if (kDebugMode) print('Artists endpoint not found');
        return [];
      } else {
        throw Exception('Failed to fetch artists: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      if (kDebugMode) print('Fetch artists error: $e');
      return []; // Fallback to empty list
    }
  }
}