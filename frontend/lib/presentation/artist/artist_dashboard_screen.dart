import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/datasources/song/song_service.dart';
import '../../core/config/constants.dart';
import '../providers/song_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';

final songServiceProvider = Provider<SongService>((ref) => SongService());

class ArtistDashboardScreen extends ConsumerStatefulWidget {
  const ArtistDashboardScreen({super.key});

  @override
  ConsumerState<ArtistDashboardScreen> createState() => _ArtistDashboardScreenState();
}

class _ArtistDashboardScreenState extends ConsumerState<ArtistDashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _selectedGenre;
  PlatformFile? _audioFile;
  PlatformFile? _coverImage;
  bool _isLoading = false;
  String? _currentPlayingSongId;
  late Future<List<Map<String, dynamic>>> _fetchSongsFuture;

  static const List<String> musicGenres = [
    'Pop', 'Rock', 'Hip Hop', 'Jazz', 'Classical',
    'Electronic', 'R&B', 'Country', 'Reggae', 'Metal', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).fetchProfile();
      _fetchSongsFuture = _fetchSongs();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchSongs() async {
    final token = ref.read(userProvider).token ?? '';
    return ref.read(songServiceProvider).fetchMySongs(token);
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'flac', 'm4a'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        final fileSize = platformFile.size;
        if (fileSize > 50 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file must be less than 50MB')),
          );
          return;
        }
        setState(() => _audioFile = platformFile);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        final fileSize = platformFile.size;
        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cover image must be less than 5MB')),
          );
          return;
        }
        setState(() => _coverImage = platformFile);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _uploadTrack() async {
    if (!_formKey.currentState!.validate()) return;

    if (_audioFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final token = ref.read(userProvider).token ?? '';
    final artistId = ref.read(userProvider).user?.id ?? '';

    try {
      final success = await ref.read(songProvider.notifier).uploadSong(
        token: token,
        title: _titleController.text.trim(),
        genre: _selectedGenre ?? musicGenres[0],
        description: _descriptionController.text.trim(),
        artistId: artistId,
        audioFile: _audioFile!,
        coverImage: _coverImage,
      );

      if (!mounted) return;
      if (success) {
        // Refresh authentication profile after successful upload
        await ref.read(userProvider.notifier).fetchProfile();
        // Show creative success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.music_note, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Epic! Your track "${_titleController.text}" is now live! 🎉 Check it out in My Songs!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF1DB954),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // Reset form and refresh songs
        _resetForm();
        setState(() => _fetchSongsFuture = _fetchSongs());
        // Redirect to My Songs tab
        if (DefaultTabController.of(context).index != 1) {
          DefaultTabController.of(context).animateTo(1); // Index 1 is My Songs tab
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playSong(String songId, String audioUrl) async {
    try {
      if (_currentPlayingSongId == songId) {
        await _audioPlayer.pause();
        setState(() => _currentPlayingSongId = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
        setState(() => _currentPlayingSongId = songId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play song: $e')),
      );
    }
  }

  Future<void> _editSongTitle(String songId, String currentTitle) async {
    final user = ref.read(userProvider).user;
    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to edit songs')),
      );
      return;
    }

    final songs = await _fetchSongs();
    final song = songs.firstWhere(
          (s) => s['_id'] == songId,
      orElse: () => <String, dynamic>{},
    );
    if (song.isEmpty || song['artistId'] != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not own this song or it does not exist')),
      );
      return;
    }

    final newTitleController = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text('Edit Song Title', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: newTitleController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new title',
            hintStyle: TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => context.pop(newTitleController.text),
            child: const Text('Save', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle != currentTitle && mounted) {
      try {
        final token = ref.read(userProvider).token ?? '';
        if (token.isEmpty) {
          await ref.read(userProvider.notifier).fetchProfile();
          if (!mounted) return;
        }
        await ref.read(songServiceProvider).updateSongTitle(token, songId, newTitle);
        setState(() => _fetchSongsFuture = _fetchSongs());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.edit, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Success! "$newTitle" has been updated! 🎵',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF1DB954),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteSong(String songId) async {
    final user = ref.read(userProvider).user;
    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to delete songs')),
      );
      return;
    }

    // Fetch the latest songs to ensure the list is current
    final songs = await _fetchSongs();
    final song = songs.firstWhere(
          (s) => s['_id'] == songId,
      orElse: () => <String, dynamic>{},
    );
    if (song.isEmpty || song['artistId'] != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not own this song or it does not exist')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text('Delete Song', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this song?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final token = ref.read(userProvider).token ?? '';
        if (token.isEmpty) {
          await ref.read(userProvider.notifier).fetchProfile();
          if (!mounted) return;
        }
        await ref.read(songServiceProvider).deleteSong(token, songId);
        setState(() => _fetchSongsFuture = _fetchSongs());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Success! Song has been deleted! 🗑️',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF1DB954),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedGenre = null;
      _audioFile = null;
      _coverImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).user;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              context.pop();
            },
          ),
          title: Text(
            'Welcome, ${user?.fullName ?? 'Artist'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: Theme.of(context).appBarTheme.elevation,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upload Music'),
              Tab(text: 'My Songs'),
              Tab(text: 'Analytics'),
            ],
            indicatorColor: Color(0xFF1DB954),
            labelColor: Color(0xFF1DB954),
            unselectedLabelColor: Colors.white54,
          ),
        ),
        body: TabBarView(
          children: [
            _buildUploadTab(),
            _buildMyMusicTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Music',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Track Title',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (val) => val?.isEmpty ?? true ? 'Please enter a track title' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGenre,
              items: musicGenres.map((genre) => DropdownMenuItem(
                value: genre,
                child: Text(genre, style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (val) => setState(() => _selectedGenre = val),
              decoration: const InputDecoration(
                labelText: 'Genre',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF212121),
              validator: (val) => val == null ? 'Please select a genre' : null,
              hint: const Text('Select a genre', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildFilePicker(
              title: 'Audio File',
              fileName: _audioFile?.name,
              onPressed: _pickAudioFile,
            ),
            const SizedBox(height: 16),
            _buildFilePicker(
              title: 'Cover Image',
              fileName: _coverImage?.name,
              onPressed: _pickCoverImage,
            ),
            const SizedBox(height: 24),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF1DB954))
                  : CustomButton(
                text: 'Upload Track',
                color: Color(0xFF1DB954),
                isFullWidth: true,
                onPressed: _uploadTrack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMusicTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchSongsFuture,
      builder: (context, snapshot) {
        print('FutureBuilder state: ${snapshot.connectionState}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
        }
        if (snapshot.hasError) {
          print('Fetch songs error: ${snapshot.error}');
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
                  onPressed: () {
                    setState(() {
                      _fetchSongsFuture = _fetchSongs();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No songs uploaded yet.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final songs = snapshot.data!;
        print('Songs fetched: ${songs.length}');
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            print('Rendering song: ${song['title']} - Cover: ${song['coverImagePath']}');
            final isPlaying = _currentPlayingSongId == song['_id'];

            return Card(
              color: const Color(0xFF212121),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: song['coverImagePath'] != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    '$baseUrl${song['coverImagePath']}',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Failed to load image for ${song['title']}: $error');
                      return const Icon(
                        Icons.image_not_supported,
                        color: Colors.white70,
                        size: 50,
                      );
                    },
                  ),
                )
                    : const Icon(Icons.music_note, color: Colors.white70, size: 50),
                title: Text(
                  song['title'] ?? 'Untitled',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Genre: ${song['genre'] ?? 'Unknown genre'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _editSongTitle(song['_id'], song['title'] ?? 'Untitled'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSong(song['_id']),
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: isPlaying ? Color(0xFF1DB954) : Colors.white70,
                      ),
                      onPressed: () => _playSong(song['_id'], '$baseUrl${song['audioPath']}'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Text(
        'Analytics coming soon',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildFilePicker({
    required String title,
    required String? fileName,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  fileName ?? 'Drag and drop your ${title.toLowerCase()} here or click to browse',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.upload, color: Colors.white70),
                onPressed: onPressed,
              ),
            ],
          ),
        ),
        Text(
          title == 'Audio File'
              ? 'MP3, WAV, FLAC, or M4A up to 50MB'
              : 'JPG, PNG, or WEBP up to 5MB',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}