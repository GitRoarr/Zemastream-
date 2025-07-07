import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/artist/artist_service.dart';

final artistServiceProvider = Provider<ArtistService>((ref) => ArtistService());