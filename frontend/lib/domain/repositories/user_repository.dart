import '../entities/user.dart';

abstract class UserRepository {
  Future<User> register(String fullName, String email, String password, String role);
  Future<User> login(String email, String password);
  Future<User> getProfile(String token);
  Future<void> logout();
}
