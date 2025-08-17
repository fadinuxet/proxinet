import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/serendipity_models.dart';

class AvailablePeoplePage extends StatefulWidget {
  const AvailablePeoplePage({super.key});

  @override
  State<AvailablePeoplePage> createState() => _AvailablePeoplePageState();
}

class _AvailablePeoplePageState extends State<AvailablePeoplePage> {
  List<Map<String, dynamic>> _availablePeople = [];
  bool _isLoading = true;
  late ColorScheme _colorScheme;

  @override
  void initState() {
    super.initState();
    _colorScheme = Theme.of(context).colorScheme;
    _loadAvailablePeople();
  }

  Future<void> _loadAvailablePeople() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await FirebaseFirestore.instance
          .collection('availability')
          .where('isAvailable', isEqualTo: true)
          .where('until', isGreaterThan: Timestamp.now())
          .get();

      final availablePeople = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final userId = doc.id;

          // Get user profile details
          final userProfile = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userProfile.exists) {
            final profileData = userProfile.data()!;
            availablePeople.add({
              'id': userId,
              'name': profileData['displayName'] ?? 'Available User',
              'email': profileData['email'] ?? '',
              'photoUrl': profileData['photoURL'],
              'audience': data['audience'] ?? 'firstDegree',
              'until': data['until'],
              'updatedAt': data['updatedAt'],
            });
          }
        } catch (e) {
          print('Error loading user profile: $e');
        }
      }

      if (mounted) {
        setState(() {
          _availablePeople = availablePeople;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading available people: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimeRemaining(Timestamp? until) {
    if (until == null) return 'Unknown';
    
    final now = DateTime.now();
    final expiry = until.toDate();
    final difference = expiry.difference(now);
    
    if (difference.isNegative) return 'Expired';
    
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m remaining';
    } else {
      return '${difference.inMinutes}m remaining';
    }
  }

  String _formatAudience(String audience) {
    switch (audience) {
      case 'firstDegree':
        return '1st Degree';
      case 'secondDegree':
        return '2nd Degree';
      case 'custom':
        return 'Custom Groups';
      default:
        return audience;
    }
  }

  Color _getAudienceColor(String audience) {
    switch (audience) {
      case 'firstDegree':
        return Colors.green;
      case 'secondDegree':
        return Colors.blue;
      case 'custom':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.people,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Available People',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _colorScheme.onSurface,
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailablePeople,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availablePeople.isEmpty
              ? _buildEmptyState()
              : _buildAvailablePeopleList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: _colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No one is available right now',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later or set your own availability!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/proxinet/availability'),
            icon: const Icon(Icons.add),
            label: const Text('Set My Availability'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePeopleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availablePeople.length,
      itemBuilder: (context, index) {
        final person = _availablePeople[index];
        return _buildPersonCard(person);
      },
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> person) {
    final audience = person['audience'] as String;
    final audienceColor = _getAudienceColor(audience);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _colorScheme.primaryContainer,
          backgroundImage: person['photoUrl'] != null
              ? NetworkImage(person['photoUrl'])
              : null,
          child: person['photoUrl'] == null
              ? Icon(
                  Icons.person,
                  color: _colorScheme.onPrimaryContainer,
                  size: 24,
                )
              : null,
        ),
        title: Text(
          person['name'],
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatTimeRemaining(person['until']),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: audienceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: audienceColor.withOpacity(0.3)),
              ),
              child: Text(
                _formatAudience(audience),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: audienceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: FilledButton.icon(
          onPressed: () => _connectToPerson(person),
          icon: const Icon(Icons.connect_without_contact, size: 16),
          label: const Text('Connect'),
          style: FilledButton.styleFrom(
            backgroundColor: _colorScheme.primary,
            foregroundColor: _colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  void _connectToPerson(Map<String, dynamic> person) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection request sent to ${person['name']}'),
        backgroundColor: _colorScheme.primary,
        action: SnackBarAction(
          label: 'View Chat',
          onPressed: () => context.push('/proxinet/messages'),
        ),
      ),
    );
  }
}
