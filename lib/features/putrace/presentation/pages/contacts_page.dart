import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/putrace_presence_sync_service.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _isLoading = false;
  Map<int, List<Map<String, dynamic>>> _connectionsByDegree = {};
  List<Map<String, dynamic>> _importedContacts = [];
  List<Map<String, dynamic>> _phoneContacts = [];
  List<Map<String, dynamic>> _pendingContactRequests = [];
  
  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadPendingContactRequests();
  }
  
  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Load connections by degree from graph_edges
      final connectionsQuery = await FirebaseFirestore.instance
          .collection('graph_edges')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      
      final connectionsByDegree = <int, List<Map<String, dynamic>>>{};
      
      for (final doc in connectionsQuery.docs) {
        final data = doc.data();
        final degree = data['degree'] as int? ?? 1;
        final peerId = data['peerId'] as String;
        
        // Get peer profile
        final profileDoc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(peerId)
            .get();
        
        if (profileDoc.exists) {
          final profile = profileDoc.data()!;
          final connection = {
            'id': peerId,
            'name': profile['name'] ?? 'Unknown User',
            'email': profile['email'] ?? '',
            'company': profile['company'] ?? '',
            'title': profile['title'] ?? '',
            'avatarUrl': profile['avatarUrl'],
            'type': 'connection',
            'degree': degree,
          };
          
          if (!connectionsByDegree.containsKey(degree)) {
            connectionsByDegree[degree] = [];
          }
          connectionsByDegree[degree]!.add(connection);
        }
      }
      
      // Load imported LinkedIn contacts
      final contactsQuery = await FirebaseFirestore.instance
          .collection('contact_tokens')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      
      final contacts = <Map<String, dynamic>>[];
      for (final doc in contactsQuery.docs) {
        final data = doc.data();
        contacts.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Contact',
          'email': data['email'] ?? '',
          'company': data['company'] ?? '',
          'title': data['title'] ?? '',
          'type': 'imported',
        });
      }
      
      // Load phone contacts
      await _loadPhoneContacts();
      
      setState(() {
        _connectionsByDegree = connectionsByDegree;
        _importedContacts = contacts;
      });
      
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error loading connections: $e');
      
      // Set demo data as fallback
      setState(() {
        _connectionsByDegree = {
          1: [
            {
              'id': 'demo_1',
              'name': 'Demo Contact 1',
              'email': 'demo1@example.com',
              'company': 'Demo Company',
              'title': 'Demo Title',
              'type': 'connection',
              'degree': 1,
            },
            {
              'id': 'demo_2',
              'name': 'Demo Contact 2',
              'email': 'demo2@example.com',
              'company': 'Demo Company',
              'title': 'Demo Title',
              'type': 'connection',
              'degree': 1,
            },
          ],
        };
        _importedContacts = [
          {
            'id': 'demo_imported_1',
            'name': 'Demo Imported Contact',
            'email': 'imported@example.com',
            'company': 'Demo Company',
            'title': 'Demo Title',
            'type': 'imported',
          },
        ];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using demo data. Some features may be limited.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadPhoneContacts() async {
    try {
      // For now, we'll show placeholder phone contacts
      // In the future, we can implement proper phone contacts integration
      setState(() {
        _phoneContacts = [
          {
            'id': 'phone_1',
            'name': 'Phone Contact 1',
            'phone': '+1234567890',
            'type': 'phone',
          },
          {
            'id': 'phone_2', 
            'name': 'Phone Contact 2',
            'phone': '+0987654321',
            'type': 'phone',
          },
        ];
      });
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error loading imported contacts: $e');
    }
  }

  Future<void> _loadPendingContactRequests() async {
    try {
      final presenceSync = GetIt.instance<PutracePresenceSyncService>();
      final requests = await presenceSync.getPendingContactRequests();
      
      if (mounted) {
        setState(() {
          _pendingContactRequests = requests;
        });
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error loading pending contact requests: $e');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Container(
                    color: scheme.surface,
                    child: TabBar(
                      labelColor: scheme.primary,
                      unselectedLabelColor: scheme.onSurfaceVariant,
                      indicatorColor: scheme.primary,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people, size: 20),
                              const SizedBox(width: 8),
                              Text('Network'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pending_actions, size: 20),
                              const SizedBox(width: 8),
                              Text('Requests (${_pendingContactRequests.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contact_mail, size: 20),
                              const SizedBox(width: 8),
                              Text('Imported (${_importedContacts.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone, size: 20),
                              const SizedBox(width: 8),
                              Text('Phone (${_phoneContacts.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildNetworkTab(),
                        _buildContactRequestsTab(),
                        _buildImportedContactsTab(),
                        _buildPhoneContactsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildNetworkTab() {
    final totalConnections = _connectionsByDegree.values
        .fold(0, (total, connections) => total + connections.length);
    
    if (totalConnections == 0) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Network Yet',
        subtitle: 'Your connections will appear here once you start networking.',
        actionText: 'Import LinkedIn Contacts',
        onAction: () => context.go('/putrace/connect'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _connectionsByDegree.length,
      itemBuilder: (context, index) {
        final degree = _connectionsByDegree.keys.elementAt(index);
        final connections = _connectionsByDegree[degree]!;
        return _buildDegreeSection(degree, connections);
      },
    );
  }
  
  Widget _buildDegreeSection(int degree, List<Map<String, dynamic>> connections) {
    final scheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Icon(
                degree == 1 ? Icons.people : Icons.people_outline,
                color: degree == 1 ? scheme.primary : scheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$degree${_getOrdinalSuffix(degree)} Degree Connections (${connections.length})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: degree == 1 ? scheme.primary : scheme.secondary,
                ),
              ),
            ],
          ),
        ),
        ...connections.map((connection) => _buildContactCard(connection, scheme: scheme)),
        const SizedBox(height: 16),
      ],
    );
  }
  
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
  
  Widget _buildContactRequestsTab() {
    if (_pendingContactRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pending_actions_outlined,
        title: 'No Pending Requests',
        subtitle: 'You have no pending contact requests.',
        actionText: 'Send Request',
        onAction: () => context.go('/putrace/connect'),
      );
    }

    return Column(
      children: [
        // Header with refresh button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pending Contact Requests',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadPendingContactRequests,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh requests',
              ),
            ],
          ),
        ),
        // Requests list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingContactRequests.length,
            itemBuilder: (context, index) {
              final request = _pendingContactRequests[index];
              return _buildContactRequestCard(request, scheme: Theme.of(context).colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactRequestCard(Map<String, dynamic> request, {required ColorScheme scheme}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['fromUserName'] ?? 'Unknown User',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (request['fromUserEmail']?.isNotEmpty == true)
                        Text(
                          request['fromUserEmail'],
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (request['message']?.isNotEmpty == true) ...[
              Text(
                request['message'],
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (request['context']?.isNotEmpty == true)
              Text(
                'Context: ${request['context']}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectContactRequest(request['requestId']),
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approveContactRequest(request['requestId']),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveContactRequest(String requestId) async {
    try {
      final presenceSync = GetIt.instance<PutracePresenceSyncService>();
      final success = await presenceSync.approveContactRequest(requestId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact request approved!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload the data
        await _loadPendingContactRequests();
        await _loadContacts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectContactRequest(String requestId) async {
    try {
      final presenceSync = GetIt.instance<PutracePresenceSyncService>();
      final success = await presenceSync.rejectContactRequest(requestId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact request declined'),
            backgroundColor: Colors.orange,
          ),
        );
        // Reload the data
        await _loadPendingContactRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPhoneContactsTab() {
    if (_phoneContacts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.phone_outlined,
        title: 'No Phone Contacts',
        subtitle: 'Import your phone contacts to see them here.',
        actionText: 'Import Phone Contacts',
        onAction: _loadPhoneContacts,
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _phoneContacts.length,
      itemBuilder: (context, index) {
        final contact = _phoneContacts[index];
        return _buildContactCard(contact, scheme: Theme.of(context).colorScheme);
      },
    );
  }
  
  Widget _buildImportedContactsTab() {
    if (_importedContacts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.contact_mail_outlined,
        title: 'No Imported Contacts',
        subtitle: 'Import your LinkedIn contacts to start building your network.',
        actionText: 'Import LinkedIn Contacts',
        onAction: () => context.go('/putrace/connect'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _importedContacts.length,
      itemBuilder: (context, index) {
        final contact = _importedContacts[index];
        return _buildContactCard(contact, scheme: Theme.of(context).colorScheme);
      },
    );
  }
  
  Widget _buildContactCard(Map<String, dynamic> contact, {required ColorScheme scheme}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.1),
          child: contact['avatarUrl'] != null
              ? ClipOval(
                  child: Image.network(
                    contact['avatarUrl'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.person, color: scheme.primary),
                  ),
                )
              : Icon(Icons.person, color: scheme.primary),
        ),
        title: Text(
          contact['name'] ?? 'Unknown',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact['title']?.isNotEmpty ?? false)
              Text(contact['title'], style: TextStyle(fontSize: 12)),
            if (contact['company']?.isNotEmpty ?? false)
              Text(contact['company'], style: TextStyle(fontSize: 12)),
            if (contact['email']?.isNotEmpty ?? false)
              Text(contact['email'], style: TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: contact['type'] == 'connection' 
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            contact['type'] == 'connection' ? '1st°' : 'Imported',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: contact['type'] == 'connection' 
                  ? scheme.primary
                  : scheme.secondary,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }
}
