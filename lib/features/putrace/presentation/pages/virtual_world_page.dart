import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VirtualWorldPage extends StatefulWidget {
  const VirtualWorldPage({super.key});

  @override
  State<VirtualWorldPage> createState() => _VirtualWorldPageState();
}

class _VirtualWorldPageState extends State<VirtualWorldPage> {
  GoogleMapController? _mapController;
  Set<Marker> _userMarkers = {};
  
  // Mock global user data
  final List<Map<String, dynamic>> _globalUsers = [
    {
      'name': 'Sarah Chen',
      'title': 'AI Researcher',
      'location': LatLng(37.7749, -122.4194), // San Francisco
      'timezone': 'PST',
      'availability': 'Now - 2PM PST',
      'skills': ['AI', 'Machine Learning', 'Python'],
      'status': 'Available for chat',
      'avatar': 'SC',
    },
    {
      'name': 'Marcus Williams',
      'title': 'UX Designer',
      'location': LatLng(40.7128, -74.0060), // New York
      'timezone': 'EST',
      'availability': '9AM - 5PM EST',
      'skills': ['UX Design', 'Figma', 'User Research'],
      'status': 'Open to design discussions',
      'avatar': 'MW',
    },
    {
      'name': 'Dr. Lisa Park',
      'title': 'Data Scientist',
      'location': LatLng(51.5074, -0.1278), // London
      'timezone': 'GMT',
      'availability': '2PM - 6PM GMT',
      'skills': ['Data Science', 'R', 'Statistics'],
      'status': 'Looking for collaboration',
      'avatar': 'LP',
    },
    {
      'name': 'Alex Rodriguez',
      'title': 'Product Manager',
      'location': LatLng(35.6762, 139.6503), // Tokyo
      'timezone': 'JST',
      'availability': '10AM - 6PM JST',
      'skills': ['Product Management', 'Agile', 'Strategy'],
      'status': 'Open to product talks',
      'avatar': 'AR',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeVirtualWorld();
  }

  void _initializeVirtualWorld() {
    _createUserMarkers();
  }

  void _createUserMarkers() {
    _userMarkers = _globalUsers.map((user) {
      return Marker(
        markerId: MarkerId(user['name']),
        position: user['location'],
        infoWindow: InfoWindow(
          title: user['name'],
          snippet: '${user['title']} • ${user['availability']}',
        ),
        onTap: () => _selectUser(user),
      );
    }).toSet();
  }

  void _selectUser(Map<String, dynamic> user) {
    _showUserProfile(user);
  }

  void _showUserProfile(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildUserProfileSheet(user),
    );
  }

  Widget _buildUserProfileSheet(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.purple.withValues(alpha: 0.1),
                child: Text(
                  user['avatar'],
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'],
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user['title'],
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      user['availability'],
                      style: GoogleFonts.inter(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ONLINE',
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Skills
          Text(
            'Skills & Expertise',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user['skills'].map<Widget>((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  skill,
                  style: GoogleFonts.inter(
                    color: Colors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Status message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.message, color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user['status'],
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startChat(user),
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _scheduleMeeting(user),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startChat(Map<String, dynamic> user) {
    // Start real-time chat with user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat with ${user['name']}'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _scheduleMeeting(Map<String, dynamic> user) {
    // Show meeting scheduling options
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildMeetingSchedulingSheet(user),
    );
  }

  Widget _buildMeetingSchedulingSheet(Map<String, dynamic> user) {
    final meetingDurations = ['15 min', '30 min', '60 min'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Meeting with ${user['name']}',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Meeting Duration',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          ...meetingDurations.map((duration) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _selectMeetingDuration(user, duration),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.purple, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        duration,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmMeeting(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Schedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectMeetingDuration(Map<String, dynamic> user, String duration) {
    // Handle meeting duration selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${duration} meeting with ${user['name']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmMeeting(Map<String, dynamic> user) {
    // Confirm meeting scheduling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meeting scheduled with ${user['name']}'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Virtual World',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showFilters(),
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () => _showSettings(),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.public, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Global professional network active',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_globalUsers.length} ONLINE',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(20.0, 0.0), // World view
                zoom: 2,
              ),
              markers: _userMarkers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
          
          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showUserList(),
                    icon: const Icon(Icons.people),
                    label: const Text('View Professionals'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showChatRooms(),
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Chat Rooms'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUserList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildUserListSheet(),
    );
  }

  Widget _buildUserListSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Professionals',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._globalUsers.map((user) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _selectUser(user);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.purple.withValues(alpha: 0.1),
                        child: Text(
                          user['avatar'],
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'],
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${user['title']} • ${user['availability']}',
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ONLINE',
                          style: GoogleFonts.inter(
                            color: Colors.green,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showChatRooms() {
    // Show virtual chat rooms
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat rooms coming soon!')),
    );
  }

  void _showFilters() {
    // Show filtering options
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filters coming soon!')),
    );
  }

  void _showSettings() {
    // Show virtual world settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Virtual world settings coming soon!')),
    );
  }
}
