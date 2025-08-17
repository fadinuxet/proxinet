import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/serendipity_models.dart';
import '../../../../core/services/serendipity_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/firebase_repositories.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class SerendipityPostComposerPage extends StatefulWidget {
  const SerendipityPostComposerPage({super.key});

  @override
  State<SerendipityPostComposerPage> createState() =>
      _SerendipityPostComposerPageState();
}

class _SerendipityPostComposerPageState
    extends State<SerendipityPostComposerPage> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _tags = TextEditingController();
  VisibilityAudience _audience = VisibilityAudience.firstDegree;
  DateTime _startAt = DateTime.now();
  DateTime _endAt = DateTime.now().add(const Duration(days: 1));
  XFile? _image;
  bool _saving = false;
  List<String> _selectedGroupIds = const [];

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
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _text,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Attending Web Summit Nov 8-10, Berlin',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: '#conference, #Berlin',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _startAt,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (d != null) {
                          setState(() {
                            _startAt = d;
                            if (_endAt.isBefore(_startAt)) {
                              _endAt = _startAt;
                            }
                          });
                        }
                      },
                      child: Text(
                          'Start: ${_startAt.toLocal().toString().split(" ").first}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final safeInitial =
                            _endAt.isBefore(_startAt) ? _startAt : _endAt;
                        final d = await showDatePicker(
                            context: context,
                            initialDate: safeInitial,
                            firstDate: _startAt,
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (d != null) setState(() => _endAt = d);
                      },
                      child: Text(
                          'End: ${_endAt.toLocal().toString().split(" ").first}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<VisibilityAudience>(
                      value: _audience,
                      decoration:
                          const InputDecoration(labelText: 'Visibility'),
                      items: const [
                        DropdownMenuItem(
                            value: VisibilityAudience.firstDegree,
                            child: Text('1st-degree')),
                        DropdownMenuItem(
                            value: VisibilityAudience.secondDegree,
                            child: Text('2nd-degree')),
                        DropdownMenuItem(
                            value: VisibilityAudience.custom,
                            child: Text('Custom Groups')),
                      ],
                      onChanged: (v) =>
                          setState(() => _audience = v ?? _audience),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_audience == VisibilityAudience.custom)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showModalBottomSheet<List<String>>(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const _GroupsPickerSheet(),
                        );
                        if (picked != null) {
                          setState(() => _selectedGroupIds = picked);
                        }
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(_selectedGroupIds.isEmpty
                          ? 'Pick Groups'
                          : 'Groups (${_selectedGroupIds.length})'),
                    ),
                  if (_audience != VisibilityAudience.custom)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 80);
                        if (img != null) setState(() => _image = img);
                      },
                      icon: const Icon(Icons.photo),
                      label:
                          Text(_image == null ? 'Add Photo' : 'Change Photo'),
                    )
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving || _text.text.trim().isEmpty
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;

                        // Check if description has text
                        if (_text.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a description'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() => _saving = true);
                        try {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) {
                            throw Exception(
                                'User not authenticated. Please sign in again.');
                          }

                          // Try to get notification service, but don't crash if it's not available
                          NotificationService? notifier;
                          try {
                            notifier = GetIt.instance<NotificationService>();
                            await notifier.init();
                          } catch (e) {
                            print('Notification service not available: $e');
                            notifier = null;
                          }

                          String? photoUrl;
                          if (_image != null) {
                            try {
                              final name =
                                  '${DateTime.now().millisecondsSinceEpoch}_${_image!.name}';
                              final ref = FirebaseStorage.instance
                                  .ref('post_photos/$name');
                              await ref.putData(await _image!.readAsBytes());
                              photoUrl = await ref.getDownloadURL();
                            } catch (e) {
                              print('Photo upload error: $e');
                              // Continue without photo if upload fails
                            }
                          }

                          // Create post directly in Firestore for better error handling
                          final postData = {
                            'authorId': uid,
                            'text': _text.text.trim(),
                            'tags': _tags.text
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList(),
                            'photoUrl': photoUrl,
                            'visibility': _audience.name,
                            if (_audience == VisibilityAudience.custom)
                              'groupIds': _selectedGroupIds,
                            'startAt': Timestamp.fromDate(_startAt.toUtc()),
                            'endAt': Timestamp.fromDate(_endAt.toUtc()),
                            'createdAt': FieldValue.serverTimestamp(),
                            'archived': false,
                            // Required for Firestore rules - initially just the author
                            'allowedUserIds': [uid],
                          };

                          final postRef = await FirebaseFirestore.instance
                              .collection('posts')
                              .add(postData);

                          print(
                              'Post created successfully with ID: ${postRef.id}');

                          if (mounted) {
                            // Show notification if service is available
                            if (notifier != null) {
                              try {
                                notifier.showNow(
                                    title: 'Post published',
                                    body: 'We\'ll notify you of overlaps');
                              } catch (e) {
                                print('Failed to show notification: $e');
                              }
                            }
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          print('Post creation error: $e');
                          if (!mounted) return;

                          String errorMessage = 'Failed to publish post';
                          if (e.toString().contains('permission-denied')) {
                            errorMessage =
                                'Permission denied. Please check your authentication.';
                          } else if (e.toString().contains('network')) {
                            errorMessage =
                                'Network error. Please check your connection.';
                          } else {
                            errorMessage = 'Failed to publish: $e';
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _saving = false);
                          }
                        }
                      },
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Publish'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsPickerSheet extends StatefulWidget {
  const _GroupsPickerSheet();
  @override
  State<_GroupsPickerSheet> createState() => _GroupsPickerSheetState();
}

class _GroupsPickerSheetState extends State<_GroupsPickerSheet> {
  final _selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final query = FirebaseFirestore.instance
        .collection('audiences')
        .doc(uid)
        .collection('groups')
        .orderBy('name');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Select Groups',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'))
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'New group name',
                        border: OutlineInputBorder()),
                    onSubmitted: (name) async {
                      final trimmed = name.trim();
                      if (trimmed.isEmpty) return;
                      await FirebaseFirestore.instance
                          .collection('audiences')
                          .doc(uid)
                          .collection('groups')
                          .add({'name': trimmed, 'memberUserIds': []});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No groups yet'));
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final name = data['name'] as String? ?? 'Group';
                      final checked = _selected.contains(d.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(d.id);
                            } else {
                              _selected.remove(d.id);
                            }
                          });
                        },
                        title: Text(name),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: const Text('Use Selected'),
            )
          ],
        ),
      ),
    );
  }
}
