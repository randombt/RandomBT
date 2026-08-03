import 'dart:io';

class PostData {
  String name;
  String caption;
  File? image;
  int likes;
  bool liked;
  bool saved;

  PostData({
    required this.name,
    required this.caption,
    this.image,
    this.likes = 0,
    this.liked = false,
    this.saved = false,
  });
}

List<PostData> allPosts = [
  PostData(name: "Rahul", caption: "Enjoying my day 😍", likes: 125),

  PostData(name: "Aman", caption: "Gym Time 💪", likes: 98),

  PostData(name: "Neha", caption: "Coffee Time ☕", likes: 210),

  PostData(name: "Rohit", caption: "Travel ❤️", likes: 315),

  PostData(name: "Priya", caption: "Nature 🌿", likes: 180),
];
