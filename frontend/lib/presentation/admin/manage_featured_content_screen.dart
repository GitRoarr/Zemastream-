import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/datasources/admin/admin_service.dart';
import '../providers/user_provider.dart';

class ManageFeaturedContentScreen extends ConsumerStatefulWidget {
  const ManageFeaturedContentScreen({super.key});

  @override
  ManageFeaturedContentScreenState createState() => ManageFeaturedContentScreenState();
}

class ManageFeaturedContentScreenState extends ConsumerState<ManageFeaturedContentScreen> {
  late Future<List<Map<String, dynamic>>> _fetchSongsFuture;
  final AdminService _adminService = AdminService();
  String _searchQuery = '';
  List<Map<String, dynamic>> _featuredSongs = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted) return;
    _initializeFutures();
  }

  void _initializeFutures() {
    final token = ref.read(userProvider).token ?? '';
    _fetchSongsFuture = _adminService.fetchAllSongs(token);
    _loadFeaturedSongs();
  }

  Future<void> _loadFeaturedSongs() async {
    final token = ref.read(userProvider).token ?? '';
    final featured = await _adminService.fetchFeaturedSongs(token);
    setState(() {
      _featuredSongs = featured;
    });
  }

  Future<void> _toggleFeaturedSong(String songId, bool isFeatured) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      if (isFeatured) {
        await _adminService.unpinFeaturedSong(token, songId);
        setState(() {
          _featuredSongs.removeWhere((song) => song['_id'] == songId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song unpinned from featured')),
        );
      } else {
        final formKey = GlobalKey<FormState>();
        String featuredOrder = '0';

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF212121),
            title: const Text('Pin as Featured', style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: TextFormField(
                initialValue: featuredOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Featured Order',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) => value!.isEmpty ? 'Enter a valid number' : null,
                onSaved: (value) => featuredOrder = value!,
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: const Text('Pin', style: TextStyle(color: Color(0xFF1DB954))),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _adminService.pinFeaturedSong(token, songId, int.parse(featuredOrder));
          final updatedSong = (await _adminService.fetchAllSongs(token)).firstWhere((song) => song['_id'] == songId);
          setState(() {
            _featuredSongs.add(updatedSong);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song pinned as featured')),
          );
        }
      }
      _initializeFutures();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update featured status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(userProvider.select((state) => state.role?.toLowerCase()));
    if (userRole != 'admin') {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Access Denied: Admins Only',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.pop();
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop();
          },
        ),
        title: Text(
          'Manage Featured Content',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Songs',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchSongsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading songs: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _initializeFutures,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No songs found.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final songs = snapshot.data!.where((song) {
                  final title = song['title']?.toString().toLowerCase() ?? '';
                  final artistName = song['artistName']?.toString().toLowerCase() ?? '';
                  return title.contains(_searchQuery) || artistName.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isFeatured = _featuredSongs.any((fs) => fs['_id'] == song['_id']);
                    print('Song data at index $index: $song'); // Debug log
                    return Card(
                      color: const Color(0xFF212121),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: song['coverImagePath'] != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            song['coverImagePath'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 50,
                                height: 50,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Image load error for ${song['title']}: $error');
                              return const Icon(Icons.image_not_supported, color: Colors.white70, size: 50);
                            },
                          ),
                        )
                            : const Icon(Icons.music_note, color: Colors.white70, size: 50),
                        title: Text(
                          song['title'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Artist: ${song['artistName'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (song['genre'] != null)
                              Text(
                                'Genre: ${song['genre']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isFeatured ? Icons.star : Icons.star_border,
                                color: isFeatured ? const Color(0xFF1DB954) : Colors.white70,
                              ),
                              onPressed: () => _toggleFeaturedSong(song['_id'], isFeatured),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}