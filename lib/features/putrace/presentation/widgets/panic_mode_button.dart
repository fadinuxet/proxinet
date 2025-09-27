import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/panic_mode_service.dart';

class PanicModeButton extends StatefulWidget {
  final VoidCallback? onPanicActivated;
  final bool showLabel;
  final bool isCompact;
  
  const PanicModeButton({
    Key? key,
    this.onPanicActivated,
    this.showLabel = true,
    this.isCompact = false,
  }) : super(key: key);
  
  @override
  State<PanicModeButton> createState() => _PanicModeButtonState();
}

class _PanicModeButtonState extends State<PanicModeButton> {
  final PanicModeService _panicModeService = PanicModeService();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _panicModeService.panicEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (event == PanicModeEvent.activated) {
          widget.onPanicActivated?.call();
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (widget.isCompact) {
      return _buildCompactButton(colorScheme);
    }
    
    return _buildFullButton(colorScheme);
  }
  
  Widget _buildCompactButton(ColorScheme colorScheme) {
    return IconButton(
      onPressed: _isLoading ? null : _showPanicModeDialog,
      icon: Icon(
        Icons.security,
        color: Colors.red,
        size: 24,
      ),
      tooltip: 'Panic Mode - Instant Data Wipe',
    );
  }
  
  Widget _buildFullButton(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel) ...[
            Text(
              'Panic Mode',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
          ],
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _showPanicModeDialog,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.security, size: 20),
            label: Text(
              _isLoading ? 'Wiping...' : 'Activate',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showPanicModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Activate Panic Mode',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will immediately:',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildWarningItem('🗑️ Delete all local data'),
            _buildWarningItem('🔒 Clear all anonymous sessions'),
            _buildWarningItem('📱 Reset app to initial state'),
            _buildWarningItem('⚡ Cannot be undone'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Use this feature in emergency situations or when you need to completely wipe all data from your device.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _activatePanicMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Activate Panic Mode',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _activatePanicMode() async {
    setState(() => _isLoading = true);
    
    try {
      await _panicModeService.activatePanicMode(
        reason: 'User activated panic mode',
        auditLog: true,
      );
      
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Panic mode activated - all data wiped'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating panic mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
