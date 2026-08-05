import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'saved_posts_screen.dart';
import 'settings_screen.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? profileImage;
  String? profileUrl;
  String username = '';

  final FirestoreService firestoreService = FirestoreService();

  late final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  late final Stream<QuerySnapshot> _userPostsStream = firestoreService.getUserPosts(currentUid);
  late final Stream<QuerySnapshot> _followersStream = firestoreService.getFollowers(currentUid);
  late final Stream<QuerySnapshot> _followingStream = firestoreService.getFollowing(currentUid);

  final TextEditingController nameController = TextEditingController();

  final TextEditingController bioController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  final cloudinary = CloudinaryPublic('szyxahsw', 'RandomBT', cache: false);

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        elevation: 0,
        title: const Text("Your Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(onEditProfile: showEditOptions),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              backgroundImage: profileUrl != null
                  ? NetworkImage(profileUrl!)
                  : profileImage != null
                  ? FileImage(profileImage!)
                  : null,
              child: profileUrl == null && profileImage == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),

            const SizedBox(height: 15),

            Text(
              nameController.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              username.isNotEmpty ? '@$username' : bioController.text,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _userPostsStream,
                  builder: (context, snapshot) {
                    int totalPosts = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;

                    return _buildStat("Posts", totalPosts);
                  },
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: _followersStream,
                  builder: (context, snapshot) {
                    return _buildStat(
                      "Followers",
                      snapshot.hasData ? snapshot.data!.docs.length : 0,
                    );
                  },
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: _followingStream,
                  builder: (context, snapshot) {
                    return _buildStat(
                      "Following",
                      snapshot.hasData ? snapshot.data!.docs.length : 0,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: showEditOptions,
                  child: const Text("Edit Profile"),
                ),
              ),
            ),
            const SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bookmark),
                  label: const Text("Saved Posts"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedPostsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Divider(color: Colors.white24),

            StreamBuilder<QuerySnapshot>(
              stream: _userPostsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text(
                      "No Data",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final posts = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),

                  itemCount: posts.length,

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),

                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;

                    return Image.network(post["imageUrl"], fit: BoxFit.cover);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();

    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (file == null) return;

    setState(() {
      profileImage = File(file.path);
    });

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      profileUrl = response.secureUrl;

      await saveProfile();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile photo updated successfully")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed : $e")));
    }
  }

  Future<void> showEditOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1B1F2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white),
                title: const Text(
                  "Change Profile Photo",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await pickProfileImage();
                },
              ),

              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  "Edit Name & Bio",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await editProfileDialog();
                },
              ),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();

                  await prefs.setBool("isLoggedIn", false);

                  await FirebaseAuth.instance.signOut();
                  await GoogleSignIn().signOut();

                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> editProfileDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1B1F2A),
          title: const Text(
            "Edit Profile",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Name"),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Username"),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: bioController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Bio"),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  try {
                    await saveProfile();
                  } on UsernameAlreadyInUseException {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Username is already in use"),
                      ),
                    );
                    return;
                  } on ArgumentError {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Username is required")),
                    );
                    return;
                  }

                  if (!mounted) return;

                  setState(() {});

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile Updated")),
                  );
                },
                child: const Text("Save"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final updatedProfileUrl = profileUrl ?? '';
    await firestoreService.updateProfileWithUsername(
      uid: user.uid,
      fullName: nameController.text.trim(),
      username: usernameController.text,
      previousUsername: username,
      bio: bioController.text.trim(),
      profileUrl: updatedProfileUrl,
    );
    username = usernameController.text.trim();
    profileUrl = updatedProfileUrl.isEmpty ? null : updatedProfileUrl;
    await firestoreService.synchronizeProfileReferences(
      uid: user.uid,
      username: username,
      profileUrl: updatedProfileUrl,
    );
    await user.updateDisplayName(nameController.text.trim());
    await user.updatePhotoURL(updatedProfileUrl);
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await firestoreService.getUserOnce(user.uid);
    final data = snapshot.data();
    if (data == null) return;

    final storedProfileUrl = data['profileUrl']?.toString() ?? '';
    profileUrl = storedProfileUrl.isEmpty ? null : storedProfileUrl;
    username = data['username']?.toString() ?? '';
    usernameController.text = username;
    nameController.text = data['fullName']?.toString() ?? '';
    bioController.text = data['bio']?.toString() ?? '';

    if (mounted) {
      setState(() {});
    }
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

        const SizedBox(height: 5),

        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    usernameController.dispose();
    super.dispose();
  }
}
