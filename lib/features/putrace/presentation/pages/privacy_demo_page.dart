import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/professional_auth_service.dart';
import '../../../../core/services/secure_messaging_service.dart';
import '../../../../core/services/ble_conference_mode_service.dart';
import '../../../../core/models/user_profile.dart';
import '../widgets/privacy_first_widgets.dart';

/// Privacy Demo Page - Showcases enterprise-grade privacy features for professional networking
/// This page demonstrates the privacy-first architecture in action
class PrivacyDemoPage extends StatefulWidget {
  const PrivacyDemoPage({super.key});

  @override
  State<PrivacyDemoPage> createState() => _PrivacyDemoPageState();
}

class _PrivacyDemoPageState extends State<PrivacyDemoPage> {
  late final ProfessionalAuthService _professionalAuth;
  late final SecureMessagingService _secureMessaging;
  late final BLEConferenceModeService _conferenceMode;
  
  ProfessionalIdentity? _professionalIdentity;
  bool _isConferenceModeActive = false;
  int _discoveredProfessionals = 0;
  final List<Map<String, dynamic>> _demoMessages = [];

  @override
  void initState() {
    super.initState();
    _professionalAuth = GetIt.instance<ProfessionalAuthService>();
    _secureMessaging = GetIt.instance<SecureMessagingService>();
    _conferenceMode = GetIt.instance<BLEConferenceModeService>();
    
    _loadProfessionalIdentity();
    _setupDemoData();
  }

  void _loadProfessionalIdentity() async {
    try {
      final identity = await _professionalAuth.getProfessionalIdentity();
      if (mounted) {
        setState(() {
          _professionalIdentity = identity;
        });
      }
    } catch (e) {
      
    }
  }

  void _setupDemoData() {
    // Demo messages to showcase encryption
    _demoMessages.addAll([
      {
        'content': 'Hi! I saw your presentation on AI at the conference.',
        'isMe': false,
        'isEncrypted': true,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'messageType': MessageType.text,
      },
      {
        'content': 'Thanks! Would you like to discuss potential collaboration?',
        'isMe': true,
        'isEncrypted': true,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 3)),
        'messageType': MessageType.text,
      },
      {
        'content': 'Shared contact information securely',
        'isMe': false,
        'isEncrypted': true,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 1)),
        'messageType': MessageType.contactInfo,
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy-First Demo'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: _showPrivacyInfo,
            tooltip: 'Privacy Info',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildEnterpriseFeatures(),
            const SizedBox(height: 24),
            _buildConferenceModeDemo(),
            const SizedBox(height: 24),
            _buildEncryptedMessagingDemo(),
            const SizedBox(height: 24),
            _buildProfessionalIdentityDemo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Enterprise-Grade Privacy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Professional networking with Signal-level security',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.lock, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              const Text(
                'End-to-end encrypted',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.business_center, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Professional only',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enterprise Privacy Features for Professional Networking',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          icon: Icons.lock,
          title: 'End-to-End Encryption',
          description: 'All professional messages encrypted sender-to-receiver',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          icon: Icons.email,
          title: 'No Phone Required',
          description: 'Professional email-only authentication',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          icon: Icons.wifi_off,
          title: 'Offline Networking',
          description: 'BLE mesh networking for conferences',
          color: Colors.purple,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          icon: Icons.business_center,
          title: 'Professional Identity',
          description: 'Work identity separate from personal',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConferenceModeDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conference Mode (Offline Networking)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ConferenceModeBadge(
          isActive: _isConferenceModeActive,
          venueName: 'Tech Conference 2024',
          discoveredProfessionals: _discoveredProfessionals,
          onTap: _toggleConferenceMode,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _toggleConferenceMode,
          icon: Icon(_isConferenceModeActive ? Icons.stop : Icons.play_arrow),
          label: Text(_isConferenceModeActive ? 'Stop Conference Mode' : 'Start Conference Mode'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isConferenceModeActive ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEncryptedMessagingDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Encrypted Messaging Demo',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _demoMessages.length,
            itemBuilder: (context, index) {
              final message = _demoMessages[index];
              return EncryptedMessageBubble(
                content: message['content'] as String,
                isMe: message['isMe'] as bool,
                isEncrypted: message['isEncrypted'] as bool,
                timestamp: message['timestamp'] as DateTime,
                messageType: message['messageType'] as MessageType,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sendDemoMessage,
                icon: const Icon(Icons.send),
                label: const Text('Send Demo Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendContactInfo,
                icon: const Icon(Icons.contact_page),
                label: const Text('Share Contact'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfessionalIdentityDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Professional Identity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_professionalIdentity != null)
          ProfessionalIdentityCard(
            identity: _professionalIdentity!,
            showEncryptionStatus: true,
            onTap: _showIdentityDetails,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.person_add, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text(
                    'No Professional Identity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create a professional identity to use privacy features',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createProfessionalIdentity,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Professional Identity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _toggleConferenceMode() async {
    try {
      if (_isConferenceModeActive) {
        await _conferenceMode.disableConferenceMode();
        setState(() {
          _isConferenceModeActive = false;
          _discoveredProfessionals = 0;
        });
      } else {
        await _conferenceMode.enableOfflineConferenceMode(
          eventId: 'demo_conference_2024',
          venueName: 'Demo Convention Center',
          eventName: 'Privacy Demo Conference',
        );
        setState(() {
          _isConferenceModeActive = true;
          _discoveredProfessionals = 3; // Demo count
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conference mode error: $e')),
      );
    }
  }

  void _sendDemoMessage() {
    setState(() {
      _demoMessages.add({
        'content': 'This is an end-to-end encrypted message!',
        'isMe': true,
        'isEncrypted': true,
        'timestamp': DateTime.now(),
        'messageType': MessageType.text,
      });
    });
  }

  void _sendContactInfo() {
    setState(() {
      _demoMessages.add({
        'content': 'Shared professional contact information securely',
        'isMe': true,
        'isEncrypted': true,
        'timestamp': DateTime.now(),
        'messageType': MessageType.contactInfo,
      });
    });
  }

  void _createProfessionalIdentity() async {
    try {
      final identity = await _professionalAuth.createProfessionalIdentity(
        professionalEmail: 'demo@company.com',
        displayName: 'Demo Professional',
        company: 'Demo Corp',
        title: 'Senior Developer',
        skills: ['Flutter', 'Privacy', 'Security'],
      );
      
      setState(() {
        _professionalIdentity = identity;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professional identity created!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating identity: $e')),
      );
    }
  }

  void _showIdentityDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Professional Identity Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_professionalIdentity != null) ...[
              Text('Name: ${_professionalIdentity!.displayName}'),
              Text('Email: ${_professionalIdentity!.professionalEmail}'),
              if (_professionalIdentity!.company != null)
                Text('Company: ${_professionalIdentity!.company}'),
              if (_professionalIdentity!.title != null)
                Text('Title: ${_professionalIdentity!.title}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.lock, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text('End-to-end encrypted'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔒 End-to-End Encryption'),
            Text('All messages are encrypted and only readable by you and the recipient.'),
            SizedBox(height: 8),
            Text('📧 No Phone Required'),
            Text('Use professional email only - no personal phone numbers needed.'),
            SizedBox(height: 8),
            Text('🏢 Professional Identity'),
            Text('Separate work identity from personal life.'),
            SizedBox(height: 8),
            Text('📡 Offline Networking'),
            Text('Connect at conferences without internet using BLE mesh networking.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
