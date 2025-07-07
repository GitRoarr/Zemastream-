class SongEntity {
  final String title;
  final String genre;
  final String description;
  final String artistId;
  final String? audioUrl;
  final String? coverImageUrl;
  final String? artist;

  SongEntity({
    required this.title,
    required this.genre,
    required this.description,
    required this.artistId,
    this.audioUrl,
    this.coverImageUrl,
    this.artist,
  });
}