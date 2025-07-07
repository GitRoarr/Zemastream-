import 'package:dio/dio.dart';
import '../../../core/config/constants.dart';

class SearchService {
  final Dio _dio = Dio();

  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final songResponse = await _dio.get('$baseUrl/api/songs?query=$query');
      final artistResponse = await _dio.get('$baseUrl/api/artists?query=$query');

      if (songResponse.statusCode == 200 && artistResponse.statusCode == 200) {
        final songs = songResponse.data as List<dynamic>;
        final artists = artistResponse.data as List<dynamic>;
        return [
          ...songs.cast<Map<String, dynamic>>(),
          ...artists.cast<Map<String, dynamic>>(),
        ];
      } else {
        throw Exception('Failed to fetch search results: ${songResponse.statusCode} - ${artistResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching: $e');
    }
  }
}