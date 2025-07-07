import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/song/song_service.dart';
import '../../data/models/song_model.dart';
import '../../domain/entities/song_entity.dart';

final songProvider = NotifierProvider<SongNotifier, SongState>(() {
  return SongNotifier();
});

class SongNotifier extends Notifier<SongState> {
  late SongService _songService;

  @override
  SongState build() {
    _songService = SongService();
    return SongState();
  }

  Future<bool> uploadSong({
    required String token,
    required String title,
    required String genre,
    required String description,
    required String artistId,
    PlatformFile? audioFile, // Use PlatformFile instead of File for better compatibility
    PlatformFile? coverImage,
  }) async {
    state = state.copyWith(
      isUploading: true,
      message: null,
      uploadedSong: null,
      error: null,
    );

    try {
      if (audioFile == null) {
        throw Exception('Audio file is required');
      }

      final result = await _songService.uploadSong(
        token: token,
        title: title,
        genre: genre,
        description: description,
        artistId: artistId,
        audioFile: audioFile,
        coverImage: coverImage,
      );

      if (result['success'] == true && result['song'] != null) {
        state = state.copyWith(
          isUploading: false,
          uploadedSong: result['song'] as SongEntity,
          message: result['message'],
        );
        // Refresh mySongs after upload
        await fetchMySongs(token);
        return true;
      } else {
        state = state.copyWith(
          isUploading: false,
          error: result['message'] ?? 'Unknown error',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<List<SongModel>> fetchMySongs(String token) async {
    state = state.copyWith(isLoadingSongs: true, error: null);
    try {
      final songs = await _songService.fetchMySongs(token);
      final songList = songs.map((song) => SongModel.fromJson(song)).toList();
      state = state.copyWith(isLoadingSongs: false, mySongs: songList);
      return songList;
    } catch (e) {
      state = state.copyWith(isLoadingSongs: false, error: e.toString());
      return [];
    }
  }

  Future<void> incrementPlayCount(String songId, String token) async {
    state = state.copyWith(isLoadingSongs: true, error: null);
    try {
      // Call backend to increment play count
      await _songService.incrementPlayCount(songId, token);
      // Update local state
      final updatedSongs = state.mySongs?.map((song) {
        if (song.id == songId && song.playCount != null) {
          return SongModel(
            id: song.id,
            title: song.title,
            genre: song.genre,
            description: song.description,
            artistId: song.artistId,
            audioPath: song.audioPath,
            coverImagePath: song.coverImagePath,
            artist: song.artist,
            duration: song.duration,
            playCount: (song.playCount ?? 0) + 1,
          );
        }
        return song;
      }).toList();
      state = state.copyWith(mySongs: updatedSongs, isLoadingSongs: false);
    } catch (e) {
      state = state.copyWith(isLoadingSongs: false, error: e.toString());
    }
  }

  void clearUploadState() {
    state = state.copyWith(
      message: null,
      error: null,
      uploadedSong: null,
    );
  }
}

class SongState {
  final bool isUploading;
  final bool isLoadingSongs; // New field for song fetching state
  final String? message;
  final String? error;
  final SongEntity? uploadedSong;
  final List<SongModel>? mySongs; // New field to store fetched songs

  SongState({
    this.isUploading = false,
    this.isLoadingSongs = false,
    this.message,
    this.error,
    this.uploadedSong,
    this.mySongs,
  });

  SongState copyWith({
    bool? isUploading,
    bool? isLoadingSongs,
    String? message,
    String? error,
    SongEntity? uploadedSong,
    List<SongModel>? mySongs,
  }) {
    return SongState(
      isUploading: isUploading ?? this.isUploading,
      isLoadingSongs: isLoadingSongs ?? this.isLoadingSongs,
      message: message ?? this.message,
      error: error ?? this.error,
      uploadedSong: uploadedSong ?? this.uploadedSong,
      mySongs: mySongs ?? this.mySongs,
    );
  }
}