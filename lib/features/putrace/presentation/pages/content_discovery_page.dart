import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/smart_tagging_service.dart';
import '../../../../core/services/interest_matching_service.dart';
import '../../../../core/models/serendipity_models.dart';
import '../../../../core/models/user_profile.dart';

class ContentDiscoveryPage extends StatefulWidget {
  const ContentDiscoveryPage({super.key});

  @override
  State<ContentDiscoveryPage> createState() => _ContentDiscoveryPageState();
}

class _ContentDiscoveryPageState extends State<ContentDiscoveryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SmartTaggingService _taggingService = GetIt.instance<SmartTaggingService>();
  final InterestMatchingService _matchingService = GetIt.instance<InterestMatchingService>();
  // final ConnectionService _connectionService = GetIt.instance<ConnectionService>(); // Removed unused field

  List<SerendipityPost> _recommendations = [];
  List<SmartTag> _trendingTags = [];
  List<UserProfile> _similarUsers = [];
  Map<String, dynamic> _networkInsights = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load data in parallel
      final futures = await Future.wait([
        _matchingService.getPersonalizedRecommendations(userId: user.uid),
        _taggingService.getTrendingTags(),
        _matchingService.getUsersWithSimilarInterests(
          userId: user.uid,
          latitude: 37.7749, // San Francisco coordinates
          longitude: -122.4194,
        ),
        _matchingService.getNetworkInsights(user.uid),
      ]);

      setState(() {
        _recommendations = futures[0] as List<SerendipityPost>;
        _trendingTags = futures[1] as List<SmartTag>;
        _similarUsers = futures[2] as List<UserProfile>;
        _networkInsights = futures[3] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'For You', icon: Icon(Icons.recommend)),
            Tab(text: 'Trending', icon: Icon(Icons.trending_up)),
            Tab(text: 'People', icon: Icon(Icons.people)),
            Tab(text: 'Insights', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendationsTab(),
                _buildTrendingTab(),
                _buildPeopleTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_recommendations.isEmpty) {
      return _buildEmptyState(
        'No Recommendations Yet',
        'Complete your profile with skills and interests to get personalized recommendations.',
        Icons.recommend_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final post = _recommendations[index];
          return _buildRecommendationCard(post);
        },
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_trendingTags.isEmpty) {
      return _buildEmptyState(
        'No Trending Tags',
        'Tags will appear here as people start using them.',
        Icons.trending_up_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trendingTags.length,
        itemBuilder: (context, index) {
          final tag = _trendingTags[index];
          return _buildTrendingTagCard(tag);
        },
      ),
    );
  }

  Widget _buildPeopleTab() {
    if (_similarUsers.isEmpty) {
      return _buildEmptyState(
        'No Similar Users Found',
        'Complete your profile and location settings to find people with similar interests.',
        Icons.people_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _similarUsers.length,
        itemBuilder: (context, index) {
          final user = _similarUsers[index];
          return _buildSimilarUserCard(user);
        },
      ),
    );
  }

  Widget _buildInsightsTab() {
    if (_networkInsights.isEmpty) {
      return _buildEmptyState(
        'No Insights Available',
        'Build your network to see insights and recommendations.',
        Icons.analytics_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInsightCard(
            'Network Overview',
            'Total Connections: ${_networkInsights['totalConnections'] ?? 0}',
            Icons.people,
            Colors.blue,
          ),
          _buildInsightCard(
            'Network Diversity',
            'Score: ${(_networkInsights['networkDiversity'] ?? 0.0).toStringAsFixed(2)}',
            Icons.diversity_3,
            Colors.green,
          ),
          if (_networkInsights['skillGaps'] != null) ...[
            const SizedBox(height: 16),
            _buildSkillGapsCard(_networkInsights['skillGaps'] as List<String>),
          ],
          if (_networkInsights['recommendedConnections'] != null) ...[
            const SizedBox(height: 16),
            _buildRecommendationsCard(_networkInsights['recommendedConnections'] as List<String>),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(SerendipityPost post) {
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
                    post.postTypeDisplayText[0].toUpperCase(),
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
                        post.postTypeDisplayText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        post.categoryDisplayText,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.isLocationBased)
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.text,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.skills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: post.skills.take(3).map((skill) {
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.viewCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.favorite,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const Spacer(),
                Text(
                  post.createdAt.toString().substring(0, 10),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingTagCard(SmartTag tag) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            tag.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '#${tag.name}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tag.usageCount} uses • ${tag.popularity.toStringAsFixed(1)} popularity',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.trending_up,
          color: tag.popularity > 5.0 ? Colors.green : Colors.orange,
        ),
        onTap: () => _showTagDetails(tag),
      ),
    );
  }

  Widget _buildSimilarUserCard(UserProfile user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            user.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.title != null && user.company != null)
              Text('${user.title} at ${user.company}'),
            if (user.skills.isNotEmpty)
              Text(
                'Skills: ${user.skills.take(3).join(', ')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: FilledButton(
          onPressed: () => _connectWithUser(user),
          child: const Text('Connect'),
        ),
        onTap: () => _showUserProfile(user),
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    return Card(
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
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 14,
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

  Widget _buildSkillGapsCard(List<String> skillGaps) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Skills to Develop',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: skillGaps.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(List<String> recommendations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.recommend,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Network Recommendations',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((recommendation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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

  void _showTagDetails(SmartTag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('#${tag.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${tag.type.toString().split('.').last}'),
            Text('Usage: ${tag.usageCount} times'),
            Text('Popularity: ${tag.popularity.toStringAsFixed(1)}'),
            if (tag.description != null) ...[
              const SizedBox(height: 8),
              Text('Description: ${tag.description}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _connectWithUser(UserProfile user) {
    // TODO: Implement connection request
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection request sent to ${user.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showUserProfile(UserProfile user) {
    // TODO: Navigate to user profile page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${user.name}\'s profile'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
