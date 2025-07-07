import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/presentation/providers/user_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../data/models/song_model.dart';
import '../../../data/datasources/song/song_service.dart';

class PlayerState {
  final SongModel? currentMusic;
  final bool isLoading;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration duration;
  final String? error;
  final String? debugInfo;
  final bool isFavorite;
  final bool isShuffleEnabled;
  final int repeatMode; // 0: off, 1: repeat one, 2: repeat all
  final List<SongModel> queue;
  final int currentQueueIndex;

  PlayerState({
    this.currentMusic,
    this.isLoading = false,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.debugInfo,
    this.isFavorite = false,
    this.isShuffleEnabled = false,
    this.repeatMode = 0,
    this.queue = const [],
    this.currentQueueIndex = -1,
  });

  PlayerState copyWith({
    SongModel? currentMusic,
    bool? isLoading,
    bool? isPlaying,
    Duration? currentPosition,
    Duration? duration,
    String? error,
    String? debugInfo,
    bool? isFavorite,
    bool? isShuffleEnabled,
    int? repeatMode,
    List<SongModel>? queue,
    int? currentQueueIndex,
  }) {
    return PlayerState(
      currentMusic: currentMusic ?? this.currentMusic,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      error: error ?? this.error,
      debugInfo: debugInfo ?? this.debugInfo,
      isFavorite: isFavorite ?? this.isFavorite,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SongService _songService;
  final Ref _ref; // To access userProvider

  PlayerNotifier(this._songService, this._ref) : super(PlayerState()) {
    _audioPlayer.positionStream.listen((position) {
      state = state.copyWith(currentPosition: position);
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);
      if (playerState.processingState == ProcessingState.completed) {
        _handleTrackEnd();
      }
    });

    // Increment play count when playback starts
    _audioPlayer.playingStream.listen((isPlaying) {
      if (isPlaying && state.currentMusic != null && !state.isLoading) {
        _incrementPlayCountIfApplicable();
      }
    });
  }

  Future<void> loadMusic(String musicId, String token, {String? audioUrlFromQuery}) async {
    state = state.copyWith(isLoading: true, error: null, debugInfo: 'Loading music: $musicId');
    try {
      SongModel song;
      if (audioUrlFromQuery != null && audioUrlFromQuery.isNotEmpty) {
        song = SongModel(
          id: musicId,
          title: 'Unknown', // Fallback title
          genre: 'Unknown Genre', // Fallback
          description: 'No Description', // Fallback
          artistId: '', // Fallback
          audioPath: audioUrlFromQuery,
          coverImagePath: null, // Fallback, can be fetched later if needed
          artist: 'Unknown Artist', // Fallback
          duration: null,
          playCount: 0,
        );
        await _audioPlayer.setUrl(audioUrlFromQuery);
      } else {
        song = await _songService.fetchSongById(musicId, token);
        if (song.audioPath == null) {
          throw Exception('Audio URL not found');
        }
        await _audioPlayer.setUrl(song.audioPath!);
      }
      state = state.copyWith(
        currentMusic: song,
        isLoading: false,
        isFavorite: false,
        queue: [song],
        currentQueueIndex: 0,
        debugInfo: 'Loaded music: ${song.title}',
      );
      await _audioPlayer.play();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load music: $e',
        debugInfo: 'Error loading music: $e',
      );
    }
  }

  void setPlaylist(List<Map<String, dynamic>> featuredSongs, String token) async {
    state = state.copyWith(isLoading: true, error: null, debugInfo: 'Setting playlist');
    try {
      final queue = await Future.wait(featuredSongs.map((song) async {
        final songModel = await _songService.fetchSongById(song['musicId'] as String, token);
        return songModel;
      }));
      queue.sort((a, b) => (featuredSongs.firstWhere((s) => s['musicId'] == a.id)['order'] as int)
          .compareTo(featuredSongs.firstWhere((s) => s['musicId'] == b.id)['order'] as int));
      if (queue.isNotEmpty) {
        final firstSong = queue.first;
        await _audioPlayer.setUrl(firstSong.audioPath!);
        state = state.copyWith(
          currentMusic: firstSong,
          isLoading: false,
          queue: queue,
          currentQueueIndex: 0,
          debugInfo: 'Playlist set, playing: ${firstSong.title}',
        );
        await _audioPlayer.play();
      } else {
        state = state.copyWith(isLoading: false, error: 'No songs in playlist');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to set playlist: $e',
        debugInfo: 'Error setting playlist: $e',
      );
    }
  }

  void toggleFavorite() {
    state = state.copyWith(isFavorite: !state.isFavorite);
  }

  void shareMusic() {
    if (state.currentMusic == null) return;
    state = state.copyWith(debugInfo: 'Shared: ${state.currentMusic!.title}');
  }

  void toggleShuffle() {
    final isShuffling = !state.isShuffleEnabled;
    state = state.copyWith(isShuffleEnabled: isShuffling);
    if (isShuffling) {
      final newQueue = List<SongModel>.from(state.queue);
      final currentSong = newQueue[state.currentQueueIndex];
      newQueue.removeAt(state.currentQueueIndex);
      newQueue.shuffle();
      newQueue.insert(0, currentSong);
      state = state.copyWith(queue: newQueue, currentQueueIndex: 0);
    }
  }

  Future<void> skipToPrevious() async {
    if (state.currentQueueIndex > 0) {
      await _playSongAtIndex(state.currentQueueIndex - 1);
    }
  }

  Future<void> skipToNext() async {
    if (state.currentQueueIndex < state.queue.length - 1) {
      await _playSongAtIndex(state.currentQueueIndex + 1);
    } else {
      _handleTrackEnd();
    }
  }

  void toggleRepeatMode() {
    state = state.copyWith(repeatMode: (state.repeatMode + 1) % 3);
  }

  Future<void> pauseMusic() async {
    await _audioPlayer.pause();
  }

  Future<void> resumeMusic() async {
    await _audioPlayer.play();
  }

  void seekTo(int milliseconds) {
    _audioPlayer.seek(Duration(milliseconds: milliseconds));
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> _playSongAtIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(isLoading: true, currentQueueIndex: index);
    try {
      final song = state.queue[index];
      await _audioPlayer.setUrl(song.audioPath!);
      state = state.copyWith(
        currentMusic: song,
        isLoading: false,
        debugInfo: 'Playing: ${song.title}',
      );
      await _audioPlayer.play();
      _incrementPlayCountIfApplicable(); // Increment on new song play
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to play song: $e',
        debugInfo: 'Error playing song: $e',
      );
    }
  }

  Future<void> _handleTrackEnd() async {
    if (state.repeatMode == 1) {
      await _playSongAtIndex(state.currentQueueIndex);
    } else if (state.repeatMode == 2 || state.currentQueueIndex < state.queue.length - 1) {
      final nextIndex = (state.currentQueueIndex + 1) % state.queue.length;
      await _playSongAtIndex(nextIndex);
    } else {
      await _audioPlayer.stop();
      state = state.copyWith(currentPosition: Duration.zero);
    }
  }

  Future<void> _incrementPlayCountIfApplicable() async {
    final currentUser = _ref.read(userProvider);
    final currentSong = state.currentMusic;
    if (currentSong != null && currentUser.token != null) {
      // Check if the current user is not the artist of the song
      final token = currentUser.token!;
      try {
        final songDetails = await _songService.fetchSongById(currentSong.id, token);
        if (currentUser.user?.id != songDetails.artistId) {
          await _songService.incrementPlayCount(currentSong.id, token);
          state = state.copyWith(debugInfo: 'Play count incremented for: ${currentSong.title}');
        } else {
          if (kDebugMode) print('Play count not incremented: Artist playing their own song');
        }
      } catch (e) {
        state = state.copyWith(debugInfo: 'Failed to increment play count: $e');
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

// Providers
final songServiceProvider = Provider<SongService>((ref) => SongService());

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final songService = ref.read(songServiceProvider);
  return PlayerNotifier(songService, ref);
});