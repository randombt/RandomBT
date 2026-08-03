import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _searchLimit = 20;
  static const _debounceDuration = Duration(milliseconds: 400);

  final TextEditingController searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _debounce;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  String _searchText = '';
  String? _errorMessage;
  bool _isLoading = false;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    setState(() {
      _searchText = query;
      _errorMessage = null;
      if (query.isEmpty) {
        _users = [];
        _isLoading = false;
      }
    });

    if (query.isEmpty) return;

    _debounce = Timer(_debounceDuration, () => _searchUsers(query));
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted || query != _searchText) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _searchByField('username', query),
        _searchByField('fullName', query),
      ]);

      final usersById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        for (final result in results) for (final user in result.docs) user.id: user,
      };

      if (!mounted || query != _searchText) return;
      setState(() {
        _users = usersById.values.toList();
        _isLoading = false;
      });
    } on FirebaseException {
      if (!mounted || query != _searchText) return;
      setState(() {
        _users = [];
        _isLoading = false;
        _errorMessage = 'Unable to search users. Please try again.';
      });
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _searchByField(
    String field,
    String query,
  ) {
    return _firestore
        .collection('users')
        .orderBy(field)
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(_searchLimit)
        .get();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
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
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchText.isEmpty) {
      return const Center(
        child: Text(
          'Search for users',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final data = user.data();
        final profileUrl = data['profileUrl']?.toString() ?? '';
        final fullName = data['fullName']?.toString() ?? '';
        final username = data['username']?.toString() ?? '';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: profileUrl.isNotEmpty
                ? NetworkImage(profileUrl)
                : null,
            child: profileUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(
            fullName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '@$username',
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfileScreen(uid: user.id)),
            );
          },
        );
      },
    );
  }
}
