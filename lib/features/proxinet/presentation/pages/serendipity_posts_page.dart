import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/serendipity_service.dart';
import '../../../../core/services/firebase_repositories.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SerendipityPostsPage extends StatefulWidget {
  const SerendipityPostsPage({super.key});

  @override
  State<SerendipityPostsPage> createState() => _SerendipityPostsPageState();
}

class _SerendipityPostsPageState extends State<SerendipityPostsPage> {
  SerendipityService? _service;
  FirebasePostsRepo? _postsRepo;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      _service = GetIt.instance<SerendipityService>();
      _postsRepo = GetIt.instance<FirebasePostsRepo>();
    } catch (e) {
      print('Failed to initialize services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.network_check,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ProxiNet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/proxinet');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/proxinet/post'),
          ),
        ],
      ),
      body: _postsRepo == null
          ? const Center(
              child: Text('Failed to load posts service. Please restart the app.'),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _postsRepo!.myPostsStream(_uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 64, color: scheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first post to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/proxinet/post'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Post'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final hasOverlaps = post['hasOverlaps'] == true;
              final isArchived = post['archived'] == true;
              final photoUrl = post['photoUrl'] as String?;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photoUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.image, color: scheme.outline),
                            ),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.event, color: scheme.primary),
                        ),
                  title: Text(
                    post['text'] ?? '',
                    style: TextStyle(
                      decoration: isArchived ? TextDecoration.lineThrough : null,
                      color: isArchived ? scheme.outline : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      if (post['tags'] != null && (post['tags'] as List).isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: (post['tags'] as List)
                              .map((tag) => Chip(
                                    label: Text(tag.toString()),
                                    backgroundColor: scheme.secondaryContainer,
                                    labelStyle: TextStyle(
                                      color: scheme.onSecondaryContainer,
                                      fontSize: 12,
                                    ),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: scheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatDate(post['startAt'])} - ${_formatDate(post['endAt'])}',
                            style: TextStyle(
                              color: scheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (hasOverlaps)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 16,
                                color: scheme.onTertiaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Potential overlaps',
                                style: TextStyle(
                                  color: scheme.onTertiaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handlePostAction(value, post),
                    itemBuilder: (context) => [
                      if (!isArchived) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive),
                              SizedBox(width: 8),
                              Text('Archive'),
                            ],
                          ),
                        ),
                      ] else ...[
                        const PopupMenuItem(
                          value: 'unarchive',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive),
                              SizedBox(width: 8),
                              Text('Unarchive'),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      return '${timestamp.toDate().month}/${timestamp.toDate().day}';
    }
    return 'Unknown';
  }

  Future<void> _handlePostAction(String action, Map<String, dynamic> post) async {
    final postId = post['id'] as String;
    
    switch (action) {
      case 'edit':
        // Navigate to edit page (reuse composer with existing data)
        context.go('/proxinet/post', extra: post);
        break;
        
      case 'archive':
        if (_postsRepo != null) {
          await _postsRepo!.update(postId, {
            'archived': true,
            'archivedAt': FieldValue.serverTimestamp(),
          });
        }
        break;
        
      case 'unarchive':
        if (_postsRepo != null) {
          await _postsRepo!.update(postId, {
            'archived': false,
            'archivedAt': null,
          });
        }
        break;
        
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          await _deletePost(postId, post);
        }
        break;
    }
  }

  Future<void> _deletePost(String postId, Map<String, dynamic> post) async {
    try {
      // Delete photo from Storage if exists
      final photoUrl = post['photoUrl'] as String?;
      if (photoUrl != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(photoUrl);
          await ref.delete();
        } catch (e) {
          // Photo might already be deleted, continue
          print('Photo deletion error: $e');
        }
      }
      
      // Delete post from Firestore
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .delete();
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
