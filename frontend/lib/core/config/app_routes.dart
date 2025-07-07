import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/admin/admin_service.dart';
import '../../data/datasources/lib/library_service.dart';
import '../../presentation/artist/ArtistDetailScreen.dart';
import '../../presentation/admin/manage_featured_content_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/common/library_screen.dart';
import '../../presentation/common/search_screen.dart';
import '../../presentation/welcome/welcome_screen.dart';
import '../../presentation/common/main_navigation.dart';
import '../../presentation/artist/artist_dashboard_screen.dart';
import '../../presentation/admin/admin_dashboard_screen.dart';
import '../../presentation/player/player_screen.dart';
import '../../presentation/providers/user_provider.dart';
import 'constants.dart'; // Import HomeScreen

class AppRoutes {
  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String mainNav = '/main';
  static const String artistDashboard = '/artist-dashboard';
  static const String adminDashboard = '/admin-dashboard';
  static const String manageFeaturedContent = '/manage-featured-content';
  static const String artistDetail = '/artist/:id';
  static const String player = '/player/:musicId';
  static const String search = '/search';
  static const String trending = '/trending';
  static const String artists = '/artists';
  static const String newReleases = '/new-releases';
  static const String explore = '/explore';
  static const String library = '/library';
  static const String profile = '/profile';
  static const String queue = '/queue';
  static const String playlistDetail = '/playlist/:playlistId';

  static final GoRouter router = GoRouter(
    initialLocation: welcome,
    redirect: (BuildContext context, GoRouterState state) {
      final userState = ProviderScope.containerOf(context).read(userProvider);
      final isLoggedIn = userState.user != null;
      final isLoggingIn = state.matchedLocation == login || state.matchedLocation == register;
      final isWelcome = state.matchedLocation == welcome;
      final isAdmin = userState.role?.toLowerCase() == 'admin';
      final isAdminRoute = state.matchedLocation == adminDashboard || state.matchedLocation == manageFeaturedContent;

      if (!isLoggedIn && !isLoggingIn && !isWelcome) {
        return login;
      }
      if (isLoggedIn && (isLoggingIn || isWelcome)) {
        return isAdmin ? adminDashboard : '$mainNav?tab=0';
      }
      if (isAdmin && isAdminRoute) {
        return null;
      }
      if (!isAdmin && isAdminRoute) {
        return isLoggedIn ? '$mainNav?tab=0' : login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: mainNav,
        name: 'mainNav',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] != null
              ? int.tryParse(state.uri.queryParameters['tab']!)?.clamp(0, 3) ?? 0
              : 0;
          return MainNavigation(initialIndex: tab);
        },
      ),
      GoRoute(
        path: artistDashboard,
        name: 'artistDashboard',
        builder: (context, state) => const ArtistDashboardScreen(),
      ),
      GoRoute(
        path: adminDashboard,
        name: 'adminDashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: manageFeaturedContent,
        name: 'manageFeaturedContent',
        builder: (context, state) => const ManageFeaturedContentScreen(),
      ),
      GoRoute(
        path: artistDetail,
        name: 'artistDetail',
        builder: (context, state) {
          final artistId = state.pathParameters['id']!;
          return ArtistDetailScreen(artistId: artistId);
        },
      ),
      GoRoute(
        path: player,
        name: 'player',
        builder: (context, state) {
          final musicId = state.pathParameters['musicId']!;
          final audioUrl = state.uri.queryParameters['audioUrl']; // Ensure this is correctly parsed
          return PlayerScreen(musicId: musicId, audioUrl: audioUrl);
        },
      ),
      GoRoute(
        path: search,
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: trending,
        name: 'trending',
        builder: (context, state) => _buildAllSongsScreen(context, 'Trending Now', (token) => AdminService().fetchAllSongs(token)),
      ),
      GoRoute(
        path: artists,
        name: 'artists',
        builder: (context, state) => _buildAllArtistsScreen(context, 'Featured Artists'),
      ),
      GoRoute(
        path: newReleases,
        name: 'newReleases',
        builder: (context, state) => _buildAllSongsScreen(context, 'New Releases', (token) => AdminService().fetchAllSongs(token), isNewReleases: true),
      ),
      GoRoute(
        path: explore,
        name: 'explore',
        builder: (context, state) => const SizedBox(), // Placeholder for ExploreScreen (define it if needed)
      ),
      GoRoute(
        path: library,
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: queue,
        name: 'queue',
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: playlistDetail,
        name: 'playlistDetail',
        builder: (context, state) {
          final playlistId = state.pathParameters['playlistId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return PlaylistDetailScreen(
            playlist: extra?['playlist'] as Map<String, dynamic>,
            libraryService: extra?['libraryService'] as LibraryService,
            onPlay: extra?['onPlay'] as Function(String),
            onPause: extra?['onPause'] as Function(),
            isPlaying: extra?['isPlaying'] as bool,
            currentAudioUrl: extra?['currentAudioUrl'] as String?,
            onRefresh: extra?['onRefresh'] as VoidCallback,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('No route defined for ${state.uri}')),
    ),
  );

  static Widget _buildAllSongsScreen(BuildContext context, String title, Future<List<Map<String, dynamic>>> Function(String) fetchSongs, {bool isNewReleases = false}) {
    return Consumer(
      builder: (context, ref, child) {
        final adminService = ref.watch(Provider((ref) => AdminService()));
        final token = ref.watch(userProvider.select((state) => state.token)) ?? '';
        final songsFuture = fetchSongs(token);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: _songList(context, songsFuture, isNewReleases: isNewReleases),
        );
      },
    );
  }

  static Widget _buildAllArtistsScreen(BuildContext context, String title) {
    return Consumer(
      builder: (context, ref, child) {
        final adminService = ref.watch(Provider((ref) => AdminService()));
        final token = ref.watch(userProvider.select((state) => state.token)) ?? '';
        final artistsFuture = adminService.fetchAllArtists(token);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: _artistList(context, artistsFuture),
        );
      },
    );
  }

  static Widget _songList(BuildContext context, Future<List<Map<String, dynamic>>> songsFuture, {bool isNewReleases = false}) {
    return SizedBox(
      height: 220,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            print('Error loading songs: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.grey, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading songs: ${snapshot.error}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {}, // Refresh logic needs context
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No songs available.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final songs = snapshot.data!;
          final displayedSongs = isNewReleases ? songs.reversed.toList() : songs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: displayedSongs.length.clamp(0, 5), // Limit to 5 items
            itemBuilder: (context, index) {
              final song = displayedSongs[index];
              final audioUrl = '$baseUrl${song['audioPath'] ?? ''}';
              final songId = song['_id'] as String;
              return GestureDetector(
                onTap: () => context.push('/player/$songId?audioUrl=$audioUrl'),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: song['coverImagePath'] != null
                            ? Image.network(
                          '$baseUrl${song['coverImagePath']}',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 140,
                            height: 140,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        )
                            : Container(
                          width: 140,
                          height: 140,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song['title'] ?? 'Untitled',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song['artistName'] ?? 'Unknown Artist',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Widget _artistList(BuildContext context, Future<List<Map<String, dynamic>>> artistsFuture) {
    return SizedBox(
      height: 120,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: artistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            print('Error loading artists: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.grey, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading artists: ${snapshot.error}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {}, // Refresh logic needs context
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No artists available.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final artists = snapshot.data!;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: artists.length.clamp(0, 5), // Limit to 5 items
            itemBuilder: (context, index) {
              final artist = artists[index];
              final artistId = artist['_id'] as String? ?? '';
              final profileImageUrl = artist['profileImageUrl'] as String?;
              final fullName = artist['fullName'] as String? ?? 'Unknown';
              return GestureDetector(
                onTap: () => context.push('/artist/$artistId'),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: profileImageUrl != null
                            ? Image.network(
                          '$baseUrl$profileImageUrl',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                            : Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullName,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}