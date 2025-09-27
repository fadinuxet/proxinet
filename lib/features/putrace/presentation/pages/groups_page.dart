import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final TextEditingController _newGroup = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final groupsCol = FirebaseFirestore.instance
        .collection('audiences')
        .doc(uid)
        .collection('groups');
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
              'Putrace',
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
              context.go('/putrace');
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newGroup,
                    decoration: const InputDecoration(
                      labelText: 'New group name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final name = _newGroup.text.trim();
                    if (name.isEmpty) return;
                    
                    try {
                      await groupsCol.add({
                        'name': name, 
                        'memberUserIds': [],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      
                      // Clear the text field and show success
                      _newGroup.clear();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Group "$name" created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating group: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: groupsCol.orderBy('name').snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No groups yet'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? 'Group';
                    final members =
                        (data['memberUserIds'] as List?)?.cast<String>() ??
                            const <String>[];
                    return ExpansionTile(
                      title: Text(name),
                      subtitle: Text(
                          '${members.length} member${members.length == 1 ? '' : 's'}'),
                      children: [
                        _MembersEditor(
                          ownerUid: uid,
                          groupId: d.id,
                          members: members,
                        )
                      ],
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _MembersEditor extends StatefulWidget {
  final String ownerUid;
  final String groupId;
  final List<String> members;
  const _MembersEditor(
      {required this.ownerUid, required this.groupId, required this.members});

  @override
  State<_MembersEditor> createState() => _MembersEditorState();
}

class _MembersEditorState extends State<_MembersEditor> {
  final TextEditingController _uidField = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final groupRef = FirebaseFirestore.instance
        .collection('audiences')
        .doc(widget.ownerUid)
        .collection('groups')
        .doc(widget.groupId);
    final edges = FirebaseFirestore.instance
        .collection('graph_edges')
        .where('ownerId', isEqualTo: widget.ownerUid)
        .limit(50);
    final members = widget.members;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: members
                .map((m) => Chip(
                      label: Text(m),
                      onDeleted: () async {
                        final next = [...members]..remove(m);
                        await groupRef.update({'memberUserIds': next});
                        setState(() {});
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _uidField,
                  decoration: const InputDecoration(
                      labelText: 'Add member by UID',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: () async {
                    final uid = _uidField.text.trim();
                    if (uid.isEmpty) return;
                    if (!members.contains(uid)) {
                      try {
                        final next = [...members, uid];
                        await groupRef.update({'memberUserIds': next});
                        // Force rebuild of parent widget
                        if (mounted) {
                          setState(() {});
                        }
                        // Show success message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added $uid to group'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding member: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User already in group'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                    _uidField.clear();
                  },
                  child: const Text('Add'))
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: edges.snapshots(),
            builder: (context, snap) {
              final items = snap.data?.docs ?? const [];
              if (items.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Suggestions (1st-degree):',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final peer = data['peerUid'] as String? ?? '';
                      final inGroup = members.contains(peer);
                      return ActionChip(
                        label: Text(inGroup ? '$peer ✓' : peer),
                        onPressed: inGroup
                            ? null
                            : () async {
                                final next = [...members, peer];
                                await groupRef.update({'memberUserIds': next});
                                setState(() {});
                              },
                      );
                    }).toList(),
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }
}
