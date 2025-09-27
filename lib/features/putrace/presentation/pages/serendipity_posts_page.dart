import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/firebase_repositories.dart';
import 'package:go_router/go_router.dart';

class SerendipityPostsPage extends StatefulWidget {
  const SerendipityPostsPage({super.key});

  @override
  State<SerendipityPostsPage> createState() => _SerendipityPostsPageState();
}

class _SerendipityPostsPageState extends State<SerendipityPostsPage> {
  FirebasePostsRepo? _postsRepo;
  bool _showAllPosts = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      _postsRepo = GetIt.instance<FirebasePostsRepo>();
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Putrace Posts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/putrace/post'),
          ),
          IconButton(
            icon: Icon(_showAllPosts ? Icons.person : Icons.people),
            onPressed: () {
              setState(() {
                _showAllPosts = !_showAllPosts;
              });
            },
            tooltip: _showAllPosts ? 'Show My Posts' : 'Show All Posts',
          ),
        ],
      ),
      body: _postsRepo == null
          ? const Center(
              child: Text('Failed to load posts service. Please restart the app.'),
            )
          : const Center(
              child: Text('Posts service loaded successfully!'),
            ),
    );
  }
}
