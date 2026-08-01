import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'post_data.dart';
class CreatePostScreen extends StatefulWidget {
  final VoidCallback onPostUploaded;

  const CreatePostScreen({
    super.key,
    required this.onPostUploaded,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File? selectedImage;

  final ImagePicker picker = ImagePicker();

  final TextEditingController captionController = TextEditingController();

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        title: const Text("Create Post"),
      ),

body: Padding(
padding: const EdgeInsets.all(20),
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
      Icon(
        Icons.image,
        color: Colors.white54,
        size: 80,
      ),
      SizedBox(height: 10),
      Text(
        "No Image Selected",
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18,
        ),
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
  onPressed: () {

    if (selectedImage == null) return;

    allPosts.insert(
      0,
      PostData(
        name: "You",
        caption: captionController.text,
        image: selectedImage,
        likes: 0,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Post uploaded successfully"),
      ),
    );
    widget.onPostUploaded();
    setState(() {
      selectedImage = null;
      captionController.clear();
    });

  },
child: const Text(
"POST",
style: TextStyle(fontSize: 18),
),
),
),

],
),
),
    );
  }
}