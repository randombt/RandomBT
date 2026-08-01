import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}
File? profileImage;

final ImagePicker picker = ImagePicker();
class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  Future<void> pickImage() async {
    final XFile? image =
    await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        profileImage = File(image.path);
      });
    }
  }
  Future<void> signUp() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account Created Successfully")),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup Failed")),
      );
    }
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
                backgroundImage:
                profileImage != null ? FileImage(profileImage!) : null,
                child: profileImage == null
                    ? const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 50,
                )
                    : null,
              ),

              const SizedBox(height: 15),

              TextButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Choose Profile Photo"),
              ),

              const SizedBox(height: 25),

              buildField(Icons.person, "Full Name"),
              const SizedBox(height: 15),

              buildField(Icons.alternate_email, "Username"),
              const SizedBox(height: 15),

              buildField(
                Icons.email,
                "Email",
                controller: emailController,
              ),
              const SizedBox(height: 15),

              buildField(Icons.phone, "Phone Number"),
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
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                    ),
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
        prefixIcon: Icon(icon,color: Colors.grey),
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