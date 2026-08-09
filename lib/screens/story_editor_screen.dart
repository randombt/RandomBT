import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';

class StoryEditorScreen extends StatefulWidget {
  final File mediaFile;
  final String mediaType; // 'image' or 'video'

  const StoryEditorScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  String _selectedFilter = 'Normal';
  bool _isUploading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final List<String> _filters = [
    'Normal',
    'Bright',
    'Contrast',
    'Warm',
    'Cool',
    'Vintage',
    'Fade',
    'B&W',
  ];

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

  Future<void> _postStory() async {
    if (_isUploading) return;
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userSnapshot = await _firestoreService.getUserOnce(user.uid);
      if (!mounted) return;

      final userData = userSnapshot.data();
      final username = userData?['username']?.toString() ?? 'User';
      final profileUrl = userData?['profileUrl']?.toString() ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading story...")),
      );

      final mediaUrl = await CloudinaryService.uploadImage(widget.mediaFile.path);
      if (!mounted) return;

      if (mediaUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story upload failed. Please check connection.")),
        );
        return;
      }

      await _firestoreService.uploadStory(
        uid: user.uid,
        username: username,
        profileUrl: profileUrl,
        mediaUrl: mediaUrl,
        mediaType: widget.mediaType,
        filterName: _selectedFilter,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Story posted successfully!")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post story: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorFilter = _getColorFilter(_selectedFilter);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: _isUploading ? null : () => Navigator.pop(context),
                  ),
                  const Text(
                    "New Story",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _isUploading ? null : _postStory,
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Share",
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Story Media Preview with Filter
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: colorFilter != null
                        ? ColorFiltered(
                            colorFilter: colorFilter,
                            child: Image.file(widget.mediaFile),
                          )
                        : Image.file(widget.mediaFile),
                  ),
                ),
              ),
            ),

            // Horizontal Filter Selector at the bottom
            Container(
              height: 110,
              color: Colors.black54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  final filterMatrix = _getColorFilter(filter);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? Colors.blueAccent : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: filterMatrix != null
                                  ? ColorFiltered(
                                      colorFilter: filterMatrix,
                                      child: Image.file(widget.mediaFile),
                                    )
                                  : Image.file(widget.mediaFile),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.blueAccent : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
