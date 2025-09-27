import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/anonymous_privacy_service.dart';

class AnonymousPrivacySettings extends StatefulWidget {
  const AnonymousPrivacySettings({Key? key}) : super(key: key);
  
  @override
  State<AnonymousPrivacySettings> createState() => _AnonymousPrivacySettingsState();
}

class _AnonymousPrivacySettingsState extends State<AnonymousPrivacySettings> {
  final AnonymousPrivacyService _privacyService = AnonymousPrivacyService();
  
  bool _isPrivacyModeEnabled = true;
  bool _hasUserConsent = false;
  PrivacyReport? _privacyReport;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }
  
  Future<void> _loadPrivacySettings() async {
    try {
      _isPrivacyModeEnabled = _privacyService.isPrivacyModeEnabled;
      _hasUserConsent = _privacyService.hasUserConsent;
      _privacyReport = await _privacyService.generatePrivacyReport();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPrivacyStatusCard(colorScheme),
          const SizedBox(height: 16),
          _buildPrivacyModeCard(colorScheme),
          const SizedBox(height: 16),
          _buildDataManagementCard(colorScheme),
          const SizedBox(height: 16),
          _buildPrivacyReportCard(colorScheme),
          const SizedBox(height: 16),
          _buildActionsCard(colorScheme),
        ],
      ),
    );
  }
  
  Widget _buildPrivacyStatusCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _hasUserConsent ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasUserConsent ? Icons.verified_user : Icons.warning,
                  color: _hasUserConsent ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasUserConsent ? 'Privacy Protected' : 'Privacy Consent Required',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _hasUserConsent 
                          ? 'Your data is protected with privacy-first design'
                          : 'Grant consent to use anonymous features',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrivacyModeCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Mode',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When enabled, all data is stored locally and automatically cleaned up.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isPrivacyModeEnabled,
              onChanged: _hasUserConsent ? (value) async {
                if (value) {
                  await _privacyService.enablePrivacyMode();
                } else {
                  await _privacyService.disablePrivacyMode();
                }
                setState(() {
                  _isPrivacyModeEnabled = value;
                });
              } : null,
              title: Text(
                'Enable Privacy Mode',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _isPrivacyModeEnabled 
                  ? 'Maximum privacy protection active'
                  : 'Standard privacy protection',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDataManagementCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Management',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.blue),
              title: Text(
                'Rotate Session',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Generate new anonymous session ID',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              onTap: _hasUserConsent ? () async {
                await _privacyService.forceSessionRotation();
                await _loadPrivacySettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Session rotated successfully')),
                );
              } : null,
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                'Clear All Data',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Remove all locally stored data',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              onTap: _hasUserConsent ? () => _showClearDataDialog() : null,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrivacyReportCard(ColorScheme colorScheme) {
    if (_privacyReport == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Report',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildReportItem('Privacy Score', _privacyReport!.privacyScore, _getScoreColor(_privacyReport!.privacyScore)),
            _buildReportItem('Data Points', _privacyReport!.dataPoints.toString(), colorScheme.onSurface),
            _buildReportItem('Session History', _privacyReport!.sessionHistoryCount.toString(), colorScheme.onSurface),
            _buildReportItem('Data Age', _privacyReport!.dataAge, colorScheme.onSurface),
            if (_privacyReport!.lastSessionRotation != null)
              _buildReportItem('Last Rotation', _formatDateTime(_privacyReport!.lastSessionRotation!), colorScheme.onSurface),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportItem(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Actions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (!_hasUserConsent) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  await _privacyService.grantConsent();
                  await _loadPrivacySettings();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Grant Privacy Consent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () => _showRevokeConsentDialog(),
                icon: const Icon(Icons.cancel),
                label: const Text('Revoke Consent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getScoreColor(String score) {
    switch (score) {
      case 'High':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
  
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Data'),
        content: Text('This will permanently delete all locally stored data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _privacyService.revokeConsent();
              await _loadPrivacySettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All data cleared successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear Data'),
          ),
        ],
      ),
    );
  }
  
  void _showRevokeConsentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke Privacy Consent'),
        content: Text('This will revoke your privacy consent and clear all data. You will need to grant consent again to use anonymous features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _privacyService.revokeConsent();
              await _loadPrivacySettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Privacy consent revoked')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Revoke'),
          ),
        ],
      ),
    );
  }
}
