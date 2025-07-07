import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/user/auth_service.dart';
import '../../data/models/user_model.dart';

final userProvider = NotifierProvider<UserNotifier, UserState>(UserNotifier.new);

class UserNotifier extends Notifier<UserState> {
  late final AuthService _authService;
  late final FlutterSecureStorage _localStorage;

  @override
  UserState build() {
    _authService = AuthService();
    _localStorage = const FlutterSecureStorage();
    return UserState(role: null);
  }

  Future<void> initializeUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _localStorage.read(key: 'jwt_token');
      if (token != null) {
        final userData = {
          '_id': await _localStorage.read(key: 'user_id') ?? '',
          'fullName': await _localStorage.read(key: 'user_fullName') ?? '',
          'email': await _localStorage.read(key: 'user_email') ?? '',
          'role': await _localStorage.read(key: 'user_role') ?? '',
        };
        state = state.copyWith(
          user: UserModel.fromJson(userData),
          token: token,
          role: userData['role'],
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authService.register(fullName, email, password, role);
      state = state.copyWith(
        user: UserModel.fromJson(response['user']),
        token: response['token'],
        role: response['user']['role'],
        isLoading: false,
      );
      await _saveUserData(response['token'], response['user']);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authService.login(email, password);
      state = state.copyWith(
        user: UserModel.fromJson(response['user']),
        token: response['token'],
        role: response['user']['role'],
        isLoading: false,
      );
      await _saveUserData(response['token'], response['user']);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await getCurrentToken();
      if (token != null) {
        final user = await _authService.getProfile(token);
        state = state.copyWith(user: user, role: user.role, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: 'No token available');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfileImage(String token, String userId, Uint8List imageBytes, String fileName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _authService.updateProfileImage(token, userId, imageBytes, fileName);
      state = state.copyWith(user: updatedUser, role: updatedUser.role, isLoading: false);
      // Optionally save the updated profile image URL to local storage
      await _localStorage.write(key: 'user_profileImage', value: updatedUser.profileImage ?? '');
    } catch (e) {

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setUser(UserModel user, String token, String role) {
    state = UserState(user: user, token: token, role: role);
  }

  Future<void> _saveUserData(String token, Map<String, dynamic> user) async {
    await _localStorage.write(key: 'jwt_token', value: token);
    await _localStorage.write(key: 'user_id', value: user['_id']);
    await _localStorage.write(key: 'user_fullName', value: user['fullName'] ?? '');
    await _localStorage.write(key: 'user_email', value: user['email'] ?? '');
    await _localStorage.write(key: 'user_role', value: user['role'] ?? '');
    await _localStorage.write(key: 'user_profileImage', value: user['profileImage'] ?? '');
  }

  void logout() {
    _localStorage.deleteAll();
    state = UserState(role: null);
  }

  Future<String?> getCurrentToken() async {
    return state.token ?? await _localStorage.read(key: 'jwt_token');
  }
}

class UserState {
  final UserModel? user;
  final String? token;
  final String? role;
  final bool isLoading;
  final String? error;

  UserState({
    this.user,
    this.token,
    this.role,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserModel? user,
    String? token,
    String? role,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      user: user ?? this.user,
      token: token ?? this.token,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
