import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/models/user_model.dart';
import '../datasources/user/user_remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<User> register(String fullName, String email, String password, String role) async {
    final data = await remoteDataSource.register(fullName, email, password, role);
    return UserModel.fromJson(data['user']);
  }

  @override
  Future<User> login(String email, String password) async {
    final data = await remoteDataSource.login(email, password);
    return UserModel.fromJson(data['user']);
  }

  @override
  Future<User> getProfile(String token) async {
    final data = await remoteDataSource.getProfile(token);
    return UserModel.fromJson(data);
  }

  @override
  Future<void> logout() async {
    // No local storage to clear, so this can be left empty or removed
  }
}
