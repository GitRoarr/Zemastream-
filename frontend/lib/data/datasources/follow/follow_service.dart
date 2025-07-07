import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../core/config/constants.dart';

class FollowService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status! < 500,
    ),
  );

  Future<bool> checkFollowStatus(String artistId, String token) async {
    try {
      if (kDebugMode) print('Checking follow status for artistId: $artistId with token: $token');
      final response = await _dio.get(
        '/api/follow/status/$artistId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data['isFollowing'] ?? false;
      } else {
        if (kDebugMode) print('Unexpected status code ${response.statusCode} for /api/follow/status/$artistId: ${response.data}');
        return false;
      }
    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) print('Dio error checking follow status: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        if (kDebugMode) print('Check follow status error: $e');
      }
      return false;
    }
  }

  Future<bool> toggleFollow(String artistId, String token) async {
    try {
      if (kDebugMode) print('Toggling follow for artistId: $artistId with token: $token');
      final response = await _dio.post(
        '/api/follow/toggle',
        data: {'artistId': artistId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data['isFollowing'] ?? false;
      } else {
        if (kDebugMode) print('Unexpected status code ${response.statusCode} for /api/follow/toggle: ${response.data}');
        return false;
      }
    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) print('Dio error toggling follow: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        if (kDebugMode) print('Toggle follow error: $e');
      }
      return false;
    }
  }

  Future<int> getFollowersCount(String artistId, String token) async {
    try {
      if (kDebugMode) print('Fetching followers count for artistId: $artistId with token: $token');
      final response = await _dio.get(
        '/api/follow/count/$artistId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data['count'] ?? 0;
      } else {
        if (kDebugMode) print('Unexpected status code ${response.statusCode} for /api/follow/count/$artistId: ${response.data}');
        return 0;
      }
    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) print('Dio error fetching followers count: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        if (kDebugMode) print('Get followers count error: $e');
      }
      return 0;
    }
  }
}