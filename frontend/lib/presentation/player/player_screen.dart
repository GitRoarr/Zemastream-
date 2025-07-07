import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../providers/player_provider.dart';
import '../providers/user_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String musicId;
  final String? audioUrl; // Optional parameter from AppRoutes

  const PlayerScreen({super.key, required this.musicId, this.audioUrl});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = ref.read(userProvider).token;
      if (token != null) {
        // Fetch full song details and load into player
        ref.read(playerProvider.notifier).loadMusic(widget.musicId, token, audioUrlFromQuery: widget.audioUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication required. Please log in.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('ArifMusic', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              playerState.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: playerState.isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.toggleFavorite();
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.shareMusic();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF1A1A1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: playerState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.green))
            : playerState.error != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text(playerState.error!, style: const TextStyle(color: Colors.white)),
              TextButton(
                onPressed: () {
                  final token = ref.read(userProvider).token;
                  if (token != null) {
                    notifier.loadMusic(widget.musicId, token, audioUrlFromQuery: widget.audioUrl);
                  }
                },
                child: const Text('Retry', style: TextStyle(color: AppColors.green)),
              ),
            ],
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: playerState.currentMusic?.coverImagePath != null
                    ? CachedNetworkImage(
                  imageUrl: playerState.currentMusic!.coverImagePath!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: AppColors.green)),
                  errorWidget: (context, url, error) {
                    if (kDebugMode) print('Error loading cover image: $error');
                    return const Icon(Icons.music_note, color: Colors.white, size: 120);
                  },
                )
                    : const Icon(Icons.music_note, color: Colors.white, size: 120),
              ),
            ),
            const SizedBox(height: 32),
            Flexible(
              child: Text(
                playerState.currentMusic?.title ?? 'Unknown',
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.fade,
                softWrap: false,
                textAlign: TextAlign.center,
              ),
            ),
            GestureDetector(
              onTap: () {
                final artistId = playerState.currentMusic?.artistId;
                if (artistId != null) {
                  context.push('/artist/$artistId');
                }
              },
              child: Text(
                playerState.currentMusic?.artist ?? 'Unknown Artist',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (playerState.debugInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  playerState.debugInfo!,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 24),
            Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final tapPos = box.globalToLocal(details.globalPosition).dx;
                    final percent = tapPos / box.size.width;
                    final newPosition =
                    (playerState.duration.inMilliseconds * percent).toInt();
                    notifier.seekTo(newPosition);
                  },
                  child: Slider(
                    value: playerState.currentPosition.inMilliseconds.toDouble(),
                    max: playerState.duration.inMilliseconds
                        .toDouble()
                        .clamp(1, double.infinity),
                    onChanged: (value) => notifier.seekTo(value.toInt()),
                    activeColor: AppColors.green,
                    inactiveColor: Colors.grey,
                    thumbColor: AppColors.green,
                    min: 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatTime(playerState.currentPosition.inMilliseconds),
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(_formatTime(playerState.duration.inMilliseconds),
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.shuffle,
                      color: playerState.isShuffleEnabled ? AppColors.green : Colors.grey),
                  onPressed: playerState.isLoading
                      ? null
                      : () {
                    HapticFeedback.lightImpact();
                    notifier.toggleShuffle();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                  onPressed: playerState.isLoading ? null : notifier.skipToPrevious,
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: playerState.isLoading
                        ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                        : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: playerState.isPlaying
                          ? const Icon(Icons.pause,
                          key: ValueKey('pause'),
                          color: Colors.white,
                          size: 36)
                          : const Icon(Icons.play_arrow,
                          key: ValueKey('play'),
                          color: Colors.white,
                          size: 36),
                    ),
                    onPressed: playerState.isLoading
                        ? null
                        : () {
                      HapticFeedback.lightImpact();
                      playerState.isPlaying
                          ? notifier.pauseMusic()
                          : notifier.resumeMusic();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                  onPressed: playerState.isLoading ? null : notifier.skipToNext,
                ),
                IconButton(
                  icon: Icon(
                    playerState.repeatMode == 1 ? Icons.repeat_one : Icons.repeat,
                    color: playerState.repeatMode > 0 ? AppColors.green : Colors.grey,
                  ),
                  onPressed: playerState.isLoading
                      ? null
                      : () {
                    HapticFeedback.lightImpact();
                    notifier.toggleRepeatMode();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int timeMs) {
    final totalSeconds = timeMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}