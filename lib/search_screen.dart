import 'package:flutter/material.dart';
import 'post_data.dart';
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();

  final List<String> users = [
    "Rahul",
    "Aman",
    "Priya",
    "RandomBT",
    "FlutterDev",
    "Rohit",
    "Neha",
    "Karan",
    "Anjali",
    "Sakshi",
  ];

  String searchText = "";

  @override
  Widget build(BuildContext context) {
    final filteredUsers = users.where((user) {
      return user.toLowerCase().contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        title: const Text("Search"),
      ),

      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search users...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xff1B1E24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

    Expanded(
    child: GridView.builder(
    padding: const EdgeInsets.all(4),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 2,
    mainAxisSpacing: 2,
    ),
    itemCount: allPosts.length,
    itemBuilder: (context, index) {
    final post = allPosts[index];

    if (post.image == null) {
    return Container(
    color: Colors.grey.shade800,
    child: const Icon(
    Icons.image,
    color: Colors.white,
    ),
    );
    }

    return Image.file(
    post.image!,
    fit: BoxFit.cover,
    );
    },
    ),
    ),

        ],
      ),
    );
  }
}
