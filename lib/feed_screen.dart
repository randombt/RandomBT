import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'post_data.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {

final TextEditingController commentController = TextEditingController();

List<String> comments = [
"Nice Post 🔥",
"Awesome ❤️",
];

void addComment() {
if (commentController.text.trim().isNotEmpty) {
setState(() {
comments.add(commentController.text.trim());
commentController.clear();
});
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xff0F1115),

appBar: AppBar(
backgroundColor: const Color(0xff0F1115),
elevation: 0,
title: const Text(
"RandomBT",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
),
),
actions: const [
Padding(
padding: EdgeInsets.only(right: 15),
child: Icon(
Icons.chat_bubble_outline,
color: Colors.white,
),
),
],
),

body: Column(
children: [

SizedBox(
height: 100,
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: 10,
itemBuilder: (context, index) {
return Padding(
padding: const EdgeInsets.all(8),
child: Column(
children: [
CircleAvatar(
radius: 30,
backgroundColor: Colors.deepPurple,
child: Text(
"${index + 1}",
style: const TextStyle(
color: Colors.white,
),
),
),
const SizedBox(height: 5),
Text(
index == 0
? "Your Story"
: "User $index",
style: const TextStyle(
color: Colors.white,
fontSize: 12,
),
),
],
),
);
},
),
),

const Divider(color: Colors.white24),
Expanded(
child: ListView.builder(
itemCount: allPosts.length,
itemBuilder: (context, index) {

final post = allPosts[index];

return Card(
color: const Color(0xff1B1E24),
margin: const EdgeInsets.all(10),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(15),
),
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Row(
children: [
CircleAvatar(
backgroundColor: Colors.deepPurple,
child: Text(
post.name[0],
style: const TextStyle(
color: Colors.white,
),
),
),

const SizedBox(width: 10),

Text(
post.name,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
),
),

const Spacer(),

const Icon(
Icons.more_vert,
color: Colors.white,
),
],
),

const SizedBox(height: 12),

post.image == null
? Container(
height: 220,
width: double.infinity,
decoration: BoxDecoration(
color: Colors.deepPurple,
borderRadius: BorderRadius.circular(12),
),
child: const Icon(
Icons.image,
color: Colors.white,
size: 80,
),
)
: ClipRRect(
borderRadius: BorderRadius.circular(12),
child: Image.file(
post.image!,
height: 220,
width: double.infinity,
fit: BoxFit.cover,
),
),

const SizedBox(height: 12),
Row(
children: [

IconButton(
onPressed: () {
setState(() {
post.liked = !post.liked;

if (post.liked) {
post.likes++;
} else {
post.likes--;
}
});
},
icon: Icon(
post.liked
? Icons.favorite
: Icons.favorite_border,
color: post.liked
? Colors.red
: Colors.white,
),
),

IconButton(
onPressed: () {
showModalBottomSheet(
context: context,
backgroundColor: const Color(0xff1B1E24),
builder: (context) {
return Padding(
padding: const EdgeInsets.all(15),
child: Column(
children: [

const Text(
"Comments",
style: TextStyle(
color: Colors.white,
fontSize: 22,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 20),

Expanded(
child: ListView.builder(
itemCount: comments.length,
itemBuilder: (context, i) {
return ListTile(
title: const Text(
"You",
style: TextStyle(
color: Colors.white,
),
),
subtitle: Text(
comments[i],
style: const TextStyle(
color: Colors.white70,
),
),
);
},
),
),

TextField(
controller: commentController,
style: const TextStyle(
color: Colors.white,
),
decoration: const InputDecoration(
hintText: "Write a comment...",
hintStyle: TextStyle(
color: Colors.grey,
),
),
),

const SizedBox(height: 10),

SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: addComment,
child: const Text("SEND"),
),
),
],
),
);
},
);
},
icon: const Icon(
Icons.mode_comment_outlined,
color: Colors.white,
),
),

IconButton(
onPressed: () async {
await Share.share(
"Check out my post on RandomBT! 🚀",
);
},
icon: const Icon(
Icons.send_outlined,
color: Colors.white,
),
),

const Spacer(),

IconButton(
onPressed: () {
setState(() {
post.saved = !post.saved;
});
},
icon: Icon(
post.saved
? Icons.bookmark
: Icons.bookmark_border,
color: Colors.white,
),
),
],
),
  Text(
    "Liked by RandomBT and ${post.likes} others",
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),

  const SizedBox(height: 5),

  Text(
    post.caption,
    style: const TextStyle(
      color: Colors.white70,
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
);
}
}