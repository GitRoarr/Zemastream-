import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../data/datasources/home/home_service.dart';
import '../../data/datasources/follow/follow_service.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  _ArtistDetailScreenState createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  late Future<Map<String, dynamic>> _fetchArtistFuture;
  late Future<List<Map<String, dynamic>>> _fetchSongsFuture;
  final HomeService _homeService = HomeService();
  final FlutterSecureStorage _localStorage = const FlutterSecureStorage();
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  int _followerCount = 0;
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print('Fetching artist with ID: "${widget.artistId}" (length: ${widget.artistId.length})');
    _fetchArtistFuture = _fetchArtistWithToken(widget.artistId);
    _fetchSongsFuture = _fetchSongsWithToken(widget.artistId);
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    setState(() => _isLoadingFollow = true);
    final token = await _localStorage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final isFollowing = await _followService.checkFollowStatus(widget.artistId, token);
        final followerCount = await _followService.getFollowersCount(widget.artistId, token);
        setState(() {
          _isFollowing = isFollowing;
          _followerCount = followerCount;
          _isLoadingFollow = false;
        });
      } catch (e) {
        if (kDebugMode) print('Error loading follow status: $e');
        setState(() => _isLoadingFollow = false);
      }
    } else {
      setState(() => _isLoadingFollow = false);
    }
  }

  Future<Map<String, dynamic>> _fetchArtistWithToken(String artistId) async {
    final token = await _localStorage.read(key: 'jwt_token');
    try {
      final artist = await _homeService.fetchArtistById(artistId, token: token);
      if (kDebugMode) print('Fetched artist data: $artist');
      if (token != null) {
        final followerCount = await _followService.getFollowersCount(artistId, token);
        setState(() {
          _followerCount = followerCount;
        });
      }
      return artist;
    } catch (e) {
      if (kDebugMode) print('Error fetching artist: $e');
      return {
        '_id': artistId,
        'fullName': 'Unknown Artist',
        'avatarPath': null,
        'followerCount': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSongsWithToken(String artistId) async {
    final token = await _localStorage.read(key: 'jwt_token');
    try {
      final songs = await _homeService.fetchSongsByArtist(artistId, token: token);
      if (kDebugMode) print('Fetched songs for artist $artistId: $songs');
      return songs;
    } catch (e) {
      if (kDebugMode) print('Error fetching songs: $e');
      return [];
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoadingFollow) return;
    setState(() => _isLoadingFollow = true);
    final token = await _localStorage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final newFollowStatus = await _followService.toggleFollow(widget.artistId, token);
        final followerCount = await _followService.getFollowersCount(widget.artistId, token);
        setState(() {
          _isFollowing = newFollowStatus;
          _followerCount = followerCount;
          _isLoadingFollow = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? 'Following artist!' : 'Unfollowed artist.'),
            backgroundColor: _isFollowing ? Colors.green : Colors.red,
          ),
        );
      } catch (e) {
        setState(() => _isLoadingFollow = false);
        if (kDebugMode) print('Error toggling follow: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to toggle follow. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() => _isLoadingFollow = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to follow artists.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: FutureBuilder<Map<String, dynamic>>(
          future: _fetchArtistFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              );
            }
            final artist = snapshot.data ?? {
              '_id': widget.artistId,
              'fullName': 'Unknown Artist',
              'avatarPath': null,
              'followerCount': 0,
            };
            if (kDebugMode) print('AppBar artist data: $artist');
            return Text(
              artist['fullName'] as String? ?? 'Unknown Artist',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            );
          },
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchArtistFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  if (kDebugMode) print('Error in artist future: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _fetchArtistFuture = _fetchArtistWithToken(widget.artistId);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final artist = snapshot.data ?? {
                  '_id': widget.artistId,
                  'fullName': 'Unknown Artist',
                  'avatarPath': null,
                  'followerCount': 0,
                };
                if (kDebugMode) print('Body artist data: $artist');
                final imageUrl = artist['avatarPath'] as String?;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[800],
                      child: imageUrl != null
                          ? ClipOval(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) print('Image load error: $error');
                            return const Icon(Icons.person, color: Colors.white, size: 40);
                          },
                        ),
                      )
                          : const Icon(Icons.person, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artist['fullName'] as String? ?? 'Unknown Artist',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_followerCount followers',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _isLoadingFollow
                        ? const CircularProgressIndicator(color: Colors.green)
                        : ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isFollowing ? 'Following' : 'Follow'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchSongsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  if (kDebugMode) print('Error loading songs: ${snapshot.error}');
                  return Center(
                    child: Text('Error loading songs: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                  );
                }

                final songs = snapshot.data ?? [];
                if (songs.isEmpty) {
                  return const Center(child: Text('No songs available for this artist.', style: TextStyle(color: Colors.white)));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final coverImageUrl = song['coverImagePath'] as String? ?? 'https://via.placeholder.com/40x40';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            coverImageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[800],
                              width: 40,
                              height: 40,
                            ),
                          ),
                        ),
                        title: Text(
                          song['title'] as String? ?? 'Untitled',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        subtitle: Text(
                          song['artistName'] as String? ?? 'Unknown Artist',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song['duration'] as String? ?? 'N/A',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.play_circle, color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}