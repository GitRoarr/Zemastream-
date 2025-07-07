import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/follow/follow_service.dart';

final followServiceProvider = Provider<FollowService>((ref) => FollowService());
