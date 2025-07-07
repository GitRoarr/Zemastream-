import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:frontend/data/datasources/home/home_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/constants.dart';
import '../../data/datasources/admin/admin_service.dart';
import '../../data/datasources/lib/library_service.dart';
import '../providers/player_provider.dart';
import '../providers/user_provider.dart';
import 'library_screen.dart' as libScreen;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> with libScreen.RefreshableScreen {
  Future<List<Map<String, dynamic>>>? _fetchSongsFuture;
  Future<List<Map<String, dynamic>>>? _fetchArtistsFuture;
  Future<List<Map<String, dynamic>>>? _fetchWatchlistFuture;
  List<Map<String, dynamic>> _watchlist = [];
  late final HomeService _homeService;
  final LibraryService _libraryService = LibraryService();

  // Removed _audioPlayer, _currentAudioUrl, _isPlaying as they are now managed by PlayerNotifier
  String? _playlistId;
  Function? _onSongAdded;
  bool _isRefreshing = false;
  final Map<String, bool> _hoverStateMap = <String, bool>{};
  final FlutterSecureStorage _localStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _homeService = HomeService(); // Instantiate once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFutures();
      final args = ModalRoute
          .of(context)
          ?.settings
          .arguments;
      if (args is Map) {
        setState(() {
          _playlistId = args['playlistId'] as String?;
          _onSongAdded = args['onSongAdded'] as Function?;
        });
      }
    });
  }

  Future<String?> _getToken() async {
    final userState = ref.read(userProvider);
    return userState.token ?? await _localStorage.read(key: 'jwt_token');
  }

  void _initializeFutures() async {
    final token = await _getToken();
    if (kDebugMode) print('Initializing HomeScreen futures with token: $token');
    setState(() {
      _fetchSongsFuture = _homeService.fetchReleasedSongs(token: token);
      _fetchArtistsFuture = _homeService.fetchArtists(token: token);
      _fetchWatchlistFuture = token != null
          ? _libraryService.fetchWatchlist(token)
          : Future.value([]);
    });
  }
  void _playFeaturedSong(
      BuildContext context,
      WidgetRef ref,
      String musicId,
      String audioPath,
      List<Map<String, dynamic>> featuredSongs,
      ) {
    final fullAudioUrl = Uri.parse('$baseUrl$audioPath').toString(); // Ensure proper URL parsing
    print('Playing audio URL: $fullAudioUrl'); // Debug log
    final notifier = ProviderScope.containerOf(context).read(playerProvider.notifier);
    final token = ref.read(userProvider).token ?? '';

    // Load and play the music
    notifier.loadMusic(musicId, token, audioUrlFromQuery: fullAudioUrl);

    // Prepare playlist with full URLs
    final playlist = featuredSongs.map((song) => {
      'musicId': song['_id'] as String,
      'audioUrl': Uri.parse('$baseUrl${song['audioPath'] ?? ''}').toString(),
    }).toList();
    notifier.setPlaylist(playlist, token);
    notifier.resumeMusic();

    // Navigate to PlayerScreen
    context.push('/player/$musicId?audioUrl=$fullAudioUrl');
  }

  Future<List<Map<String, dynamic>>> _fetchFeaturedSongsWithToken(WidgetRef ref) async {
    final token = ref.read(userProvider).token ?? '';
    final adminService = ref.read(Provider((ref) => AdminService()));
    try {
      final featuredSongs = await adminService.fetchFeaturedSongs(token);
      print('Fetched featured songs with audio paths: $featuredSongs');
      return featuredSongs;
    } catch (e) {
      print('Error fetching featured songs: $e');
      return [];
    }
  }


  @override
  Future<void> refreshData() async {
    setState(() => _isRefreshing = true);
    final token = await _getToken();
    if (kDebugMode) print('Refreshing HomeScreen data with token: $token');
    setState(() {
      _fetchSongsFuture = _homeService.fetchReleasedSongs(token: token);
      _fetchArtistsFuture = _homeService.fetchArtists(token: token);
      _fetchWatchlistFuture = token != null
          ? _libraryService.fetchWatchlist(token)
          : Future.value([]);
    });
    await Future.wait(
        [_fetchSongsFuture!, _fetchArtistsFuture!, _fetchWatchlistFuture!]);
    setState(() => _isRefreshing = false);
  }


  Future<void> _playAudio(String audioUrl, String songId, BuildContext context,
      WidgetRef ref) async {
    if (!mounted) return;
    try {
      final token = ref
          .read(userProvider)
          .token;
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Authentication required. Please log in.')),
          );
        }
        return;
      }

      final encodedAudioUrl = Uri.encodeComponent(audioUrl);

      context.push('/player/$songId?audioUrl=$encodedAudioUrl');

      await ref.read(playerProvider.notifier).loadMusic(
          songId, token, audioUrlFromQuery: audioUrl);
    } catch (e) {
      if (mounted) {
        if (kDebugMode) print('Error playing audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Error playing audio: $e. Check file format or server.')),
        );
      }
    }
  }


  Future<void> _toggleWatchlist(String songId,
      {String section = 'unknown'}) async {
    if (!mounted) return;
    try {
      final userState = ref.read(userProvider);
      if (userState.token == null) throw Exception('No token available');

      final isInWatchlist = _watchlist.any((song) => song['_id'] == songId);

      if (isInWatchlist) {
        await _libraryService.removeFromWatchlist(userState.token, songId);
        setState(() => _watchlist.removeWhere((song) => song['_id'] == songId));
      } else {
        await _libraryService.addToWatchlist(userState.token, songId);

        final songs = await (_fetchSongsFuture ?? Future.value([]));
        final songToAdd = songs.firstWhere(
              (song) => song['_id'] == songId,
          orElse: () =>
          {
            '_id': '',
            'title': '',
            'artistName': '',
            'audioPath': '',
            'coverImagePath': '',
            'playCount': 0
          },
        );
        if (songToAdd.isNotEmpty && songToAdd['_id'] == songId) {
          setState(() => _watchlist.add(songToAdd));
        }
      }

      setState(() {
        _fetchWatchlistFuture = _libraryService.fetchWatchlist(userState.token);
      });
      await _fetchWatchlistFuture;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isInWatchlist
              ? 'Removed from'
              : 'Added to'} watchlist in $section')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error toggling watchlist in section $section: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error in $section: $e')),
        );
      }
    }
  }

  Future<void> _addToPlaylist(String playlistId, String songId,
      {String section = 'unknown'}) async {
    if (!mounted) return;
    final userState = ref.read(userProvider);
    try {
      if (userState.token == null) throw Exception('No token available');
      if (kDebugMode) print(
          'Adding songId: $songId to playlistId: $playlistId in section: $section');

      await _libraryService.addToPlaylist(userState.token, playlistId, songId);
      if (_onSongAdded != null) _onSongAdded!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song added to playlist')),
        );
      }
      if (_playlistId != null) Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) print('Error adding to playlist in section $section: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error in $section: $e')),
        );
      }
    }
  }

  Future<void> _showAddToPlaylistDialog(String songId,
      {String section = 'unknown'}) async {
    if (!mounted) return;
    final userState = ref.read(userProvider);
    if (userState.token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to add to playlists')),
        );
      }
      return;
    }
    if (_playlistId != null) {
      await _addToPlaylist(_playlistId!, songId, section: section);
      return;
    }
    final playlists = await _libraryService.fetchPlaylists(userState.token) ??
        [];
    final controller = TextEditingController();
    bool createNew = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      createNew ? 'Create New Playlist' : 'Add to Playlist',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (createNew)
                      TextField(
                        controller: controller,
                        maxLength: 25,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Playlist name',
                          hintStyle: const TextStyle(color: Colors.grey),
                          counterStyle: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.green,
                                width: 2),
                          ),
                        ),
                      )
                    else
                      if (playlists.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No playlists available. Create one to add this song.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = playlists[index];
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.queue_music,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  playlist['name'] ?? 'Untitled',
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '${playlist['songCount'] ?? 0} songs',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _addToPlaylist(playlist['_id'], songId,
                                      section: section);
                                },
                              );
                            },
                          ),
                        ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              if (createNew) {
                                final name = controller.text.trim();
                                if (name.isNotEmpty) {
                                  try {
                                    final newPlaylist =
                                    await _libraryService.createPlaylist(
                                        userState.token, name);
                                    Navigator.pop(context);
                                    await _addToPlaylist(
                                        newPlaylist['_id'], songId,
                                        section: section);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                }
                              } else {
                                setModalState(() => createNew = true);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!createNew) const Icon(Icons.add, size: 18),
                                if (!createNew) const SizedBox(width: 4),
                                Text(createNew
                                    ? 'Create & Add'
                                    : 'New Playlist'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery
                        .of(context)
                        .viewInsets
                        .bottom),
                  ],
                ),
              );
            },
          ),
    );
  }
  Future<void> _navigateToArtist(String? artistId) async {
    if (!mounted) return;
    if (artistId == null || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(artistId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid artist selected')),
      );
      return;
    }

    final homeService = ref.read(Provider((ref) => HomeService()));
    final token = await _getToken();
    final artistData = await homeService.fetchArtistById(artistId, token: token);
    if (artistData['fullName'] == 'Unknown Artist') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist not found')),
      );
      return;
    }

    try {
      if (kDebugMode) print('Navigating to /artist/$artistId');
      context.push('/artist/$artistId');
    } catch (e) {
      if (kDebugMode) print('Error navigating to artist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading artist details: $e')),
      );
    }
  } @override Widget build(BuildContext context) {

    final userState = ref.watch(userProvider);

    if (_fetchSongsFuture == null || _fetchArtistsFuture == null ||
        _fetchWatchlistFuture == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  floating: true,
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                          Icons.search, color: Colors.white, size: 24),
                      onPressed: () => context.push('/search'),
                    ),
                    IconButton(
                      icon: const Icon(
                          Icons.notifications_outlined, color: Colors.white,
                          size: 24),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: GestureDetector(
                            onTap: () => context.push('/search'),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: Icon(
                                        Icons.search, color: Colors.grey,
                                        size: 20),
                                  ),
                                  Text(
                                    'Search songs, artists...',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Fixed Featured Section to prevent overflow
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Consumer(
                            builder: (context, ref, child) {
                              late Future<List<Map<String, dynamic>>> _fetchFeaturedSongsFuture;

                              _fetchFeaturedSongsFuture = _fetchFeaturedSongsWithToken(ref);

                              return SizedBox(
                                height: 180, // Fixed height to prevent overflow
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _fetchFeaturedSongsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      );
                                    } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                                      print('Debug: Snapshot error or empty data - ${snapshot.error}');
                                      return const Center(
                                        child: Text(
                                          'No featured songs available.',
                                          style: TextStyle(color: Colors.white, fontSize: 16),
                                        ),
                                      );
                                    }

                                    final featuredSongs = snapshot.data!;
                                    print('Debug: Featured songs - $featuredSongs');

                                    final firstFeaturedSong = featuredSongs.firstWhere(
                                          (song) => (song['featuredOrder'] as int?) == 0,
                                      orElse: () => featuredSongs.isNotEmpty ? featuredSongs.first : throw Exception('No valid featured song found'),
                                    );
                                    final musicId = firstFeaturedSong['_id'] as String;
                                    final audioPath = firstFeaturedSong['audioPath'] as String?;
                                    final coverImagePath = firstFeaturedSong['coverImagePath'] as String?;
                                    final title = firstFeaturedSong['title'] as String?;
                                    final artistName = firstFeaturedSong['artistName'] as String?;

                                    return Container(
                                      height: 340,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            if (coverImagePath != null)
                                              Image.network(
                                                coverImagePath,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    color: Colors.grey[800],
                                                    child: const Icon(Icons.music_note, color: Colors.white, size: 40),
                                                  );
                                                },
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.all(16.0), // Consistent padding
                                              child: SingleChildScrollView(
                                                child: ConstrainedBox(
                                                  constraints: const BoxConstraints(
                                                    minHeight: 340, // Match container height
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Text(
                                                        'Discover Ethiopian Music',
                                                        style: TextStyle(
                                                          color: Color(0xFFA100FF),
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      RichText(
                                                        text: const TextSpan(
                                                          style: TextStyle(
                                                            color: Color(0xFF1DB954),
                                                            fontSize: 16,
                                                            height: 1.3,
                                                          ),
                                                          children: [
                                                            TextSpan(text: 'Stream the Best Ethiopian artists and '),
                                                            TextSpan(
                                                              text: 'discover new music from emerging talent 🎉',
                                                              style: TextStyle(
                                                                color: Color(0xFF1DB954),
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 20),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          SizedBox(
                                                            width: 140,
                                                            height: 45,
                                                            child: ElevatedButton.icon(
                                                              onPressed: () => _playFeaturedSong(context, ref, musicId, audioPath ?? '', featuredSongs),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: const Color(0xFF1DB954), // Green for Play Featured
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                padding: EdgeInsets.zero,
                                                                elevation: 6,
                                                              ),
                                                              icon: const Icon(Icons.play_arrow, size: 24),
                                                              label: const Text(
                                                                'Play Featured',
                                                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 16),
                                                          SizedBox(
                                                            width: 140,
                                                            height: 45,
                                                            child: ElevatedButton.icon(
                                                              onPressed: () => context.push('/explore'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: const Color(0xFF2F2F2F), // Dark grayish-black from Figma
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                padding: EdgeInsets.zero,
                                                                elevation: 6,
                                                              ),
                                                              icon: const Icon(Icons.explore, size: 24),
                                                              label: const Text(
                                                                'Explore',
                                                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        SectionHeader(
                          title: 'Trending Now',
                          onSeeAllClick: () => context.push('/trending'),
                        ),
                        _songList(context, _fetchSongsFuture!, isTrending: true,
                            ref: ref),
                        const SizedBox(height: 24),
                        SectionHeader(
                          title: 'Featured Artists',
                          onSeeAllClick: () => context.push('/artists'),
                        ),
                        _artistList(context, _fetchArtistsFuture!),
                        const SizedBox(height: 24),
                        SectionHeader(
                          title: 'New Releases',
                          onSeeAllClick: () => context.push('/new-releases'),
                        ),
                        _songList(
                            context, _fetchSongsFuture!, isNewReleases: true,
                            ref: ref),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isRefreshing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _songList(BuildContext context,
      Future<List<Map<String, dynamic>>> songsFuture,
      {bool isTrending = false, bool isNewReleases = false, required WidgetRef ref}) {
    return SizedBox(
      height: 220,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            if (kDebugMode) print('Error loading songs: ${snapshot.error}');
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
                    onPressed: () => refreshData(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
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
          final displayedSongs = isTrending
              ? songs
              : isNewReleases
              ? songs.reversed.toList()
              : songs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchWatchlistFuture!,
            builder: (context, watchlistSnapshot) {
              if (watchlistSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              final _watchlist = watchlistSnapshot.data ?? [];
              if (kDebugMode) {
                print('Watchlist updated for ${isTrending
                    ? "Trending"
                    : isNewReleases ? "New Releases" : "Unknown"}: ${_watchlist
                    .map((s) => s['_id']).toList()}');
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: displayedSongs.length,
                itemBuilder: (context, index) {
                  final song = displayedSongs[index];
                  final audioUrl = '${baseUrl}${song['audioPath'] ?? ''}';
                  final songId = song['_id'] as String;
                  if (kDebugMode) {
                    print(
                        'Rendering song: ${song['title']} with songId: $songId in ${isTrending
                            ? "Trending"
                            : isNewReleases ? "New Releases" : "Unknown"}');
                  }
                  final isInWatchlist = _watchlist.any((w) =>
                  w['_id'] == songId);
                  final isHovered = _hoverStateMap[songId] ?? false;
                  final isNewRelease = isNewReleases && index < 3;

                  // Check if coverImagePath is a full URL or relative path
                  final coverImageUrl = song['coverImagePath']
                      ?.toString()
                      .contains('http') == true
                      ? song['coverImagePath']
                      : '$baseUrl${song['coverImagePath'] ?? ''}';

                  return MouseRegion(
                    onEnter: (_) =>
                        setState(() =>
                        _hoverStateMap[songId] = true),
                    onExit: (_) =>
                        setState(() =>
                        _hoverStateMap[songId] = false),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _hoverStateMap[songId] = true);
                      },
                      onTapDown: (_) {},
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey[800],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: coverImageUrl != null &&
                                        coverImageUrl.isNotEmpty
                                        ? Image.network(
                                      coverImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error,
                                          stackTrace) =>
                                          Container(
                                            color: Colors.grey[800],
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.grey,
                                              size: 40,
                                            ),
                                          ),
                                    )
                                        : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isHovered || isNewRelease)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.play_arrow,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            onPressed: () =>
                                                _playAudio(
                                                    audioUrl, songId, context,
                                                    ref),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isNewRelease)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'New',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      color: const Color(0xFF2E2E2E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onSelected: (value) {
                                        if (kDebugMode) {
                                          print(
                                              'Selected action: $value for songId: $songId in ${isTrending
                                                  ? "Trending"
                                                  : isNewReleases
                                                  ? "New Releases"
                                                  : "Unknown"}');
                                        }
                                        if (value == 'add_to_watchlist') {
                                          _toggleWatchlist(songId,
                                              section: isTrending
                                                  ? "Trending"
                                                  : isNewReleases
                                                  ? "New Releases"
                                                  : "Unknown");
                                        } else if (value == 'add_to_playlist') {
                                          _showAddToPlaylistDialog(songId,
                                              section: isTrending
                                                  ? "Trending"
                                                  : isNewReleases
                                                  ? "New Releases"
                                                  : "Unknown");
                                        } else if (value == 'share') {
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Share functionality coming soon'),
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) =>
                                      [
                                        PopupMenuItem(
                                          value: 'add_to_watchlist',
                                          child: Row(
                                            children: [
                                              Icon(
                                                isInWatchlist
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                isInWatchlist
                                                    ? 'Remove from Watchlist'
                                                    : 'Add to Watchlist',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'add_to_playlist',
                                          child: Row(
                                            children: [
                                              Icon(Icons.playlist_add,
                                                  color: Colors.white,
                                                  size: 20),
                                              SizedBox(width: 12),
                                              Text(
                                                'Add to Playlist',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [
                                              Icon(Icons.share,
                                                  color: Colors.white,
                                                  size: 20),
                                              SizedBox(width: 12),
                                              Text(
                                                'Share',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song['title'] ?? 'Untitled',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song['artistName'] ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${song['playCount'] ?? 0} plays',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _artistList(BuildContext context,
      Future<List<Map<String, dynamic>>> artistsFuture) {
    return SizedBox(
      height: 120,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: artistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            if (kDebugMode) print('Error loading artists: ${snapshot.error}');
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
                    onPressed: refreshData,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
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
          if (kDebugMode) print('Artists data: $artists');

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              final artistId = artist['_id'] as String? ?? '';
              // Use 'avatarPath' instead of 'profileImageUrl' to match the server response
              final profileImageUrl = artist['avatarPath']?.toString().contains(
                  'http') == true
                  ? artist['avatarPath']
                  : '${baseUrl}${artist['avatarPath'] ?? ''}';
              final fullName = artist['fullName'] as String? ?? 'Unknown';
              final followerCount = artist['followerCount'] as int? ?? 0;

              if (kDebugMode) print(
                  'Rendering artist: $fullName with ID: $artistId, profileImageUrl: $profileImageUrl');

              return GestureDetector(
                onTap: () => _navigateToArtist(artistId),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: profileImageUrl != null &&
                              profileImageUrl.isNotEmpty
                              ? Image.network(
                            profileImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0]
                                        .toUpperCase() : 'U',
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
                              fullName.isNotEmpty
                                  ? fullName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          '$followerCount followers',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
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
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAllClick;

  const SectionHeader({
    super.key,
    required this.title,
    required this.onSeeAllClick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onSeeAllClick,
            child: Text(
              'View all',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}