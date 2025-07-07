import '../../domain/entities/song_entity.dart';

class SongModel extends SongEntity {
  final String id;
  final String? duration;
  final String? audioPath; // Matches backend's audioPath
  final String? coverImagePath; // Matches backend's coverImagePath
  final int? playCount; // Added playCount field

  SongModel({
    required this.id,
    required super.title,
    required super.genre,
    required super.description,
    required super.artistId,
    this.audioPath,
    this.coverImagePath,
    super.artist,
    this.duration,
    this.playCount,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      genre: json['genre'] as String? ?? 'Unknown Genre',
      description: json['description'] as String? ?? 'No Description',
      artistId: json['artistId'] as String? ?? '',
      audioPath: json['audioUrl'] as String? ?? json['audioPath'] as String?, // Handle both cases
      coverImagePath: json['coverImagePath'] as String?,
      artist: json['artistName'] as String? ?? json['artist'] as String? ?? 'Unknown Artist',
      duration: json['duration'] as String? ?? 'N/A',
      playCount: json['playCount'] as int? ?? 0, // Default to 0 if null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'genre': genre,
      'description': description,
      'artistId': artistId,
      'audioPath': audioPath,
      'coverImagePath': coverImagePath,
      'duration': duration,
      'playCount': playCount,
    };
  }
}