import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final FirestoreService firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> signUp() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
      final user = credential.user;
      if (user == null) {
        throw StateError('Unable to create the user account.');
      }

      final profileUrl = _profileImage == null
          ? ''
          : await CloudinaryService.uploadImage(_profileImage!.path) ?? '';
      await user.updateDisplayName(fullNameController.text.trim());
      await user.updatePhotoURL(profileUrl);
      await user.reload();
      await firestoreService.createUser(
        uid: user.uid,
        email: emailController.text.trim(),
        username: usernameController.text.trim(),
        fullName: fullNameController.text.trim(),
        phone: phoneController.text.trim(),
        profileUrl: profileUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account Created Successfully")),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Signup Failed")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.deepPurple,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : null,
                child: _profileImage == null
                    ? const Icon(Icons.person, color: Colors.white, size: 50)
                    : null,
              ),

              const SizedBox(height: 15),

              TextButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Choose Profile Photo"),
              ),

              const SizedBox(height: 25),

              buildField(
                Icons.person,
                "Full Name",
                controller: fullNameController,
              ),
              const SizedBox(height: 15),

              buildField(
                Icons.alternate_email,
                "Username",
                controller: usernameController,
              ),
              const SizedBox(height: 15),

              buildField(Icons.email, "Email", controller: emailController),
              const SizedBox(height: 15),

              buildField(
                Icons.phone,
                "Phone Number",
                controller: phoneController,
              ),
              const SizedBox(height: 15),

              buildField(
                Icons.lock,
                "Password",
                password: true,
                controller: passwordController,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  onPressed: signUp,
                  child: const Text(
                    "CREATE ACCOUNT",
                    style: TextStyle(fontSize: 17, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildField(
    IconData icon,
    String hint, {
    bool password = false,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      obscureText: password,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xff1B1E24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
