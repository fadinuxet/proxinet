import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/models/connection.dart';
import '../../../../core/models/user_profile.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConnectionService _connectionService = GetIt.instance<ConnectionService>();
  // final FirebasePostsRepo _firebaseRepo = GetIt.instance<FirebasePostsRepo>(); // Removed unused field

  List<Connection> _connections = [];
  List<ConnectionRequest> _pendingRequests = [];
  List<UserProfile> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load connections and requests in parallel
      final futures = await Future.wait([
        _connectionService.getUserConnections(),
        _connectionService.getPendingRequests(),
        _connectionService.getConnectionSuggestions(),
      ]);

      setState(() {
        _connections = futures[0] as List<Connection>;
        _pendingRequests = futures[1] as List<ConnectionRequest>;
        _suggestions = futures[2] as List<UserProfile>;
        _isLoading = false;
      });

      // Listen to real-time updates
      _connectionService.connectionsStream.listen((connections) {
        setState(() => _connections = connections);
      });

      _connectionService.requestsStream.listen((requests) {
        setState(() => _pendingRequests = requests);
      });
    } catch (e) {
      
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Network'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Connections', icon: Icon(Icons.people)),
            Tab(text: 'Requests', icon: Icon(Icons.pending)),
            Tab(text: 'Suggestions', icon: Icon(Icons.lightbulb)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildConnectionsTab(),
                _buildRequestsTab(),
                _buildSuggestionsTab(),
              ],
            ),
    );
  }

  Widget _buildConnectionsTab() {
    if (_connections.isEmpty) {
      return _buildEmptyState(
        'No Connections Yet',
        'Start building your professional network by connecting with people you meet!',
        Icons.people_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _connections.length,
        itemBuilder: (context, index) {
          final connection = _connections[index];
          return _buildConnectionCard(connection);
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return _buildEmptyState(
        'No Pending Requests',
        'When people send you connection requests, they\'ll appear here.',
        Icons.pending_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildSuggestionsTab() {
    if (_suggestions.isEmpty) {
      return _buildEmptyState(
        'No Suggestions Yet',
        'Complete your profile with skills and interests to get personalized connection suggestions.',
        Icons.lightbulb_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return _buildSuggestionCard(suggestion);
        },
      ),
    );
  }

  Widget _buildConnectionCard(Connection connection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            connection.typeDisplayText[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          connection.typeDisplayText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connected ${connection.formattedAge}'),
            if (connection.sharedSkills.isNotEmpty)
              Text(
                'Shared skills: ${connection.sharedSkills.take(3).join(', ')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleConnectionAction(value, connection),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'message',
              child: Row(
                children: [
                  Icon(Icons.message),
                  SizedBox(width: 8),
                  Text('Message'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'favorite',
              child: Row(
                children: [
                  Icon(Icons.favorite_border),
                  SizedBox(width: 8),
                  Text('Favorite'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove),
                  SizedBox(width: 8),
                  Text('Remove'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showConnectionDetails(connection),
      ),
    );
  }

  Widget _buildRequestCard(ConnectionRequest request) {
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    request.type.toString().split('.').last[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.type.toString().split('.').last,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        request.formattedAge,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                request.message,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (request.sharedSkills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: request.sharedSkills.take(5).map((skill) {
                  return Chip(
                    label: Text(
                      skill,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _acceptRequest(request),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(UserProfile suggestion) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            suggestion.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          suggestion.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (suggestion.title != null && suggestion.company != null)
              Text('${suggestion.title} at ${suggestion.company}'),
            if (suggestion.skills.isNotEmpty)
              Text(
                'Skills: ${suggestion.skills.take(3).join(', ')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: FilledButton(
          onPressed: () => _sendConnectionRequest(suggestion),
          child: const Text('Connect'),
        ),
        onTap: () => _showProfileDetails(suggestion),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleConnectionAction(String action, Connection connection) {
    switch (action) {
      case 'message':
        // TODO: Navigate to messaging
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messaging coming soon!')),
        );
        break;
      case 'favorite':
        _connectionService.toggleConnectionFavorite(connection.id);
        break;
      case 'remove':
        _showRemoveConnectionDialog(connection);
        break;
    }
  }

  void _acceptRequest(ConnectionRequest request) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Find the corresponding connection
      final connection = await _connectionService.getConnection(
        request.requesterId,
        request.receiverId,
      );

      if (connection != null) {
        await _connectionService.acceptConnection(connection.id);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Connection accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error accepting connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectRequest(ConnectionRequest request) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Find the corresponding connection
      final connection = await _connectionService.getConnection(
        request.requesterId,
        request.receiverId,
      );

      if (connection != null) {
        await _connectionService.rejectConnection(connection.id);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Connection declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error declining connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendConnectionRequest(UserProfile suggestion) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _connectionService.sendConnectionRequest(
        receiverId: suggestion.id,
        message: 'Hi! I\'d like to connect with you on Putrace.',
        sharedSkills: suggestion.skills.take(3).toList(),
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Connection request sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error sending request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRemoveConnectionDialog(Connection connection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Connection'),
        content: const Text(
          'Are you sure you want to remove this connection? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _connectionService.removeConnection(connection.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connection removed'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showConnectionDetails(Connection connection) {
    // TODO: Navigate to connection details page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection details coming soon!')),
    );
  }

  void _showProfileDetails(UserProfile profile) {
    // TODO: Navigate to profile details page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile details coming soon!')),
    );
  }
}
