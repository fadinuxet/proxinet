import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/serendipity_service.dart';
import '../../../../core/services/firebase_repositories.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class ReferralsPage extends StatefulWidget {
  const ReferralsPage({super.key});

  @override
  State<ReferralsPage> createState() => _ReferralsPageState();
}

class _ReferralsPageState extends State<ReferralsPage> {
  final s = GetIt.instance<SerendipityService>();
  final repo = GetIt.instance<FirebaseReferralsRepo>();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  Map<String, dynamic>? _referralData;
  List<Map<String, dynamic>> _referralHistory = [];

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('referrals')
          .doc(_uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _referralData = doc.data();
        });
      }
      
      // Load referral history
      final historySnap = await FirebaseFirestore.instance
          .collection('referrals')
          .doc(_uid)
          .collection('history')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      
      setState(() {
        _referralHistory = historySnap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      print('Error loading referral data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final credits = _referralData?['credits'] ?? 0;
    final invitedCount = _referralData?['invitedCount'] ?? 0;
    
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Credits Earned',
                  value: credits.toString(),
                  icon: Icons.stars,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Friends Invited',
                  value: invitedCount.toString(),
                  icon: Icons.people,
                  color: scheme.secondary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Invite Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withOpacity(0.8),
                  scheme.tertiaryContainer.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.share, color: scheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invite Friends',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Share Proxinet with friends and earn credits for each successful referral!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _generateAndShareInvite,
                        icon: const Icon(Icons.share),
                        label: const Text('Generate Invite Link'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _showReferralCode,
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Show Code'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Rewards Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: scheme.surfaceContainerHighest,
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How It Works',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _RewardStep(
                  number: 1,
                  title: 'Share Your Link',
                  description: 'Generate a unique invite link and share it with friends',
                  icon: Icons.link,
                ),
                _RewardStep(
                  number: 2,
                  title: 'Friend Joins',
                  description: 'When they sign up using your link, you both get credits',
                  icon: Icons.person_add,
                ),
                _RewardStep(
                  number: 3,
                  title: 'Earn Rewards',
                  description: 'Use credits to unlock premium features and boost visibility',
                  icon: Icons.card_giftcard,
                ),
              ],
            ),
          ),
          
          if (_referralHistory.isNotEmpty) ...[
            const SizedBox(height: 24),
            
            // Referral History
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            ..._referralHistory.map((item) => _ReferralHistoryItem(
              type: item['type'] ?? 'unknown',
              amount: item['amount'] ?? 0,
              timestamp: item['createdAt'],
              description: item['description'] ?? '',
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _generateAndShareInvite() async {
    try {
      final referralCode = 'PROX${_uid.substring(0, 8).toUpperCase()}';
      final inviteUrl = 'https://proxinet.app/invite/$referralCode';
      
      // Save the referral code to Firestore
      await FirebaseFirestore.instance
          .collection('referrals')
          .doc(_uid)
          .collection('codes')
          .doc(referralCode)
          .set({
        'code': referralCode,
        'url': inviteUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'uses': 0,
      });
      
      // Share the invite with better error handling
      try {
        await Share.share(
          'Join me on Proxinet - the privacy-first proximity networking app! '
          'Use my invite link: $inviteUrl\n\n'
          'Or use my referral code: $referralCode',
          subject: 'Join Proxinet with me!',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invite shared successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (shareError) {
        print('Share error: $shareError');
        // Fallback: show the invite details for manual sharing
        if (mounted) {
          _showInviteDetails(referralCode, inviteUrl);
        }
      }
    } catch (e) {
      print('Error generating invite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInviteDetails(String referralCode, String inviteUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share these details with your friends:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildInviteItem('Referral Code:', referralCode, Icons.code),
            const SizedBox(height: 12),
            _buildInviteItem('Invite Link:', inviteUrl, Icons.link),
            const SizedBox(height: 16),
            const Text(
              'Copy and paste these details to share manually.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _copyToClipboard('$referralCode\n$inviteUrl');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy All'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value),
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy to clipboard',
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showReferralCode() async {
    final referralCode = 'PROX${_uid.substring(0, 8).toUpperCase()}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Referral Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                referralCode,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this code with friends to earn referral credits!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateAndShareInvite();
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RewardStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final IconData icon;

  const _RewardStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralHistoryItem extends StatelessWidget {
  final String type;
  final int amount;
  final dynamic timestamp;
  final String description;

  const _ReferralHistoryItem({
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = type == 'credit';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCredit 
                  ? scheme.primaryContainer 
                  : scheme.secondaryContainer,
            ),
            child: Icon(
              isCredit ? Icons.add : Icons.person_add,
              color: isCredit 
                  ? scheme.primary 
                  : scheme.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCredit 
                  ? scheme.primaryContainer 
                  : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${isCredit ? '+' : ''}$amount',
              style: TextStyle(
                color: isCredit 
                    ? scheme.primary 
                    : scheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final now = DateTime.now();
      final diff = now.difference(timestamp.toDate());
      
      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    }
    return 'Unknown';
  }
}
