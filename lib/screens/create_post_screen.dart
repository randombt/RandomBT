import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback onPostUploaded;

  const CreatePostScreen({super.key, required this.onPostUploaded});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File? selectedImage;
  bool _isUploading = false;
  final FirestoreService firestoreService = FirestoreService();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final ImagePicker picker = ImagePicker();

  final TextEditingController captionController = TextEditingController();

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xff0F1115),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          selectedImage = File(croppedFile.path);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        title: const Text("Create Post"),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xff1B1E24),
                borderRadius: BorderRadius.circular(15),
              ),

              child: selectedImage == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, color: Colors.white54, size: 80),
                        SizedBox(height: 10),
                        Text(
                          "No Image Selected",
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        selectedImage!,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),

            const SizedBox(height: 20),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Select Image"),
              ),
            ),

            const SizedBox(height: 20),
            TextField(
              controller: captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Write a caption...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xff1B1E24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (_isUploading) return;

                        if (selectedImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select an image first"),
                            ),
                          );
                          return;
                        }

                        final user = auth.currentUser;
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
                          final userSnapshot = await firestoreService
                              .getUserOnce(user.uid);
                          if (!context.mounted) return;

                          final userData = userSnapshot.data();
                          if (userData == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Unable to load your profile"),
                              ),
                            );
                            return;
                          }

                          final username =
                              userData['username']?.toString() ?? '';
                          final profileUrl =
                              userData['profileUrl']?.toString() ?? '';

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Uploading post...")),
                          );

                          final imageUrl = await CloudinaryService.uploadImage(
                            selectedImage!.path,
                          );

                          if (!context.mounted) return;
                          if (imageUrl == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Image upload failed. Please check your connection.",
                                ),
                              ),
                            );
                            return;
                          }

                          await firestoreService.uploadPost(
                            uid: user.uid,
                            username: username,
                            profileUrl: profileUrl,
                            imageUrl: imageUrl,
                            caption: captionController.text,
                          );

                          if (!context.mounted) return;
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Post uploaded successfully!"),
                            ),
                          );

                          setState(() {
                            selectedImage = null;
                            captionController.clear();
                          });

                          widget.onPostUploaded();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to create post: $e"),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isUploading = false;
                            });
                          }
                        }
                      },
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("POST", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
