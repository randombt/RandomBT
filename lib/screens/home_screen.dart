import 'package:flutter/material.dart';

import 'feed_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int currentIndex = 0;

  List<Widget> get pages => [
  const FeedScreen(),
  const SearchScreen(),

  CreatePostScreen(
    onPostUploaded: () {
      setState(() {
        currentIndex = 0;
      });
    },
  ),

  NotificationsScreen(),

  const ProfileScreen(),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(

        currentIndex: currentIndex,

        backgroundColor: Colors.black,

        selectedItemColor: Colors.deepPurple,

        unselectedItemColor: Colors.grey,

        type: BottomNavigationBarType.fixed,

        onTap: (index){
          setState(() {
            currentIndex=index;
          });
        },

        items: const [

          BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home"),

          BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: "Search"),

          BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: "Upload"),

          BottomNavigationBarItem(
  icon: Icon(Icons.notifications_outlined),
  activeIcon: Icon(Icons.notifications),
  label: "Alerts",
),

          BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile"),

        ],

      ),

    );
  }
}