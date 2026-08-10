import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/story_model.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animController;
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _audioPlayer = AudioPlayer();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _playCurrentStoryAudio();
    _animController.forward();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _playCurrentStoryAudio() async {
    try {
      await _audioPlayer.stop();
      if (_currentIndex >= 0 && _currentIndex < widget.stories.length) {
        final story = widget.stories[_currentIndex];
        if (story.audioUrl != null && story.audioUrl!.isNotEmpty) {
          await _audioPlayer.setUrl(story.audioUrl!);
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      // Ignore audio playback failure gracefully
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _playCurrentStoryAudio();
        _animController.forward(from: 0.0);
      });
    } else {
      _audioPlayer.stop();
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _playCurrentStoryAudio();
        _animController.forward(from: 0.0);
      });
    } else {
      _animController.forward(from: 0.0);
    }
  }

  ColorFilter? _getColorFilter(String filterName) {
    switch (filterName) {
      case 'Bright':
        return const ColorFilter.matrix([
          1.15, 0, 0, 0, 15,
          0, 1.15, 0, 0, 15,
          0, 0, 1.15, 0, 15,
          0, 0, 0, 1, 0,
        ]);
      case 'Contrast':
        return const ColorFilter.matrix([
          1.3, 0, 0, 0, -20,
          0, 1.3, 0, 0, -20,
          0, 0, 1.3, 0, -20,
          0, 0, 0, 1, 0,
        ]);
      case 'Warm':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 20,
          0, 1.0, 0, 0, 10,
          0, 0, 0.8, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.9, 0, 0, 0, -10,
          0, 1.0, 0, 0, 10,
          0, 0, 1.3, 0, 25,
          0, 0, 0, 1, 0,
        ]);
      case 'Vintage':
        return const ColorFilter.matrix([
          0.9, 0.5, 0.1, 0, 10,
          0.3, 0.8, 0.1, 0, 5,
          0.2, 0.3, 0.5, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 'Fade':
        return const ColorFilter.matrix([
          0.8, 0.1, 0.1, 0, 30,
          0.1, 0.8, 0.1, 0, 30,
          0.1, 0.1, 0.8, 0, 30,
          0, 0, 0, 1, 0,
        ]);
      case 'B&W':
        return const ColorFilter.matrix([
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Normal':
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final story = widget.stories[_currentIndex];
    final colorFilter = _getColorFilter(story.filterName);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        onLongPressStart: (_) {
          _animController.stop();
          _audioPlayer.pause();
        },
        onLongPressEnd: (_) {
          _animController.forward();
          _audioPlayer.play();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media
            Center(
              child: colorFilter != null
                  ? ColorFiltered(
                      colorFilter: colorFilter,
                      child: Image.network(
                        story.mediaUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                      ),
                    )
                  : Image.network(
                      story.mediaUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                    ),
            ),

            // Music Badge Overlay
            if (story.musicTitle != null && story.musicTitle!.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "${story.musicTitle} • ${story.artistName ?? 'Unknown'}",
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            // Top Progress Bars and User Info
            SafeArea(
              child: Column(
                children: [
                  // Progress bars
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: widget.stories.asMap().entries.map((entry) {
                        final index = entry.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: index == _currentIndex
                                ? LinearProgressIndicator(
                                    value: _animController.value,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  )
                                : LinearProgressIndicator(
                                    value: index < _currentIndex ? 1.0 : 0.0,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // User Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: story.profileUrl.isNotEmpty
                              ? NetworkImage(story.profileUrl)
                              : null,
                          backgroundColor: Colors.grey,
                          child: story.profileUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          story.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
