import 'dart:io';
import 'package:flutter/material.dart';
import 'post_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myPosts = allPosts.where((post) => post.name == "You").toList();

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        elevation: 0,
        title: const Text("Your Profile"),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            const SizedBox(height: 20),

            const CircleAvatar(
              radius: 45,
              backgroundColor: Colors.deepPurple,
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "You",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "Flutter Developer 🚀",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                _buildStat("Posts", myPosts.length),

                _buildStat("Followers", 120),

                _buildStat("Following", 180),

              ],
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Edit Profile"),
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Divider(color: Colors.white24),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myPosts.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemBuilder: (context, index) {

                final post = myPosts[index];

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

          ],
        ),
      ),
    );
  }

  Widget _buildStat(String title, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
