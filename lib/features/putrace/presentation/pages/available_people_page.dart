import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

      // Skip Firestore queries for demo to avoid permission errors
      
      
      // Create mock data for demo
      final availablePeople = <Map<String, dynamic>>[
        {
          'id': 'demo_user_1',
          'name': 'Demo Professional',
          'title': 'Software Engineer',
          'company': 'Tech Corp',
          'distance': '0.5 km',
          'isAvailable': true,
        },
        {
          'id': 'demo_user_2', 
          'name': 'Demo Manager',
          'title': 'Product Manager',
          'company': 'Startup Inc',
          'distance': '1.2 km',
          'isAvailable': true,
        }
      ];

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

  // String _formatTimeRemaining(Timestamp? until) {
  //   if (until == null) return 'Unknown';
  //   
  //   final now = DateTime.now();
  //   final untilTime = until.toDate();
  //   final difference = untilTime.difference(now);
  //   
  //   if (difference.isNegative) {
  //     return 'Expired';
  //   }
  //   
  //   final hours = difference.inHours;
  //   final minutes = difference.inMinutes % 60;
  //   
  //   if (hours > 0) {
  //     return '${hours}h ${minutes}m left';
  //   } else {
  //     return '${minutes}m left';
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available People'),
        backgroundColor: _colorScheme.surface,
        foregroundColor: _colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availablePeople.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: _colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No one is available right now',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later or try a different location',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _availablePeople.length,
                  itemBuilder: (context, index) {
                    final person = _availablePeople[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: _colorScheme.primary.withValues(alpha: 0.1),
                              child: Text(
                                person['name'][0].toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    person['name'],
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${person['title']} at ${person['company']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: _colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        person['distance'],
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: _colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Available',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Connecting to ${person['name']}...'),
                                        backgroundColor: _colorScheme.primary,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _colorScheme.primary,
                                    foregroundColor: _colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Connect',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
