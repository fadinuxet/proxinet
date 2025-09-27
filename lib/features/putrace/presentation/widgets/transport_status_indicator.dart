import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/dual_transport_service.dart';

class TransportStatusIndicator extends StatefulWidget {
  final bool showDetails;
  final bool isCompact;
  
  const TransportStatusIndicator({
    Key? key,
    this.showDetails = false,
    this.isCompact = false,
  }) : super(key: key);
  
  @override
  State<TransportStatusIndicator> createState() => _TransportStatusIndicatorState();
}

class _TransportStatusIndicatorState extends State<TransportStatusIndicator> {
  final DualTransportService _transportService = DualTransportService();
  
  TransportMode _currentMode = TransportMode.offline;
  bool _isInternetAvailable = false;
  bool _isBLEAvailable = false;
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _initializeTransportService();
  }
  
  Future<void> _initializeTransportService() async {
    await _transportService.initialize();
    
    _transportService.transportEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentMode = _transportService.currentMode;
          _isInternetAvailable = _transportService.isInternetAvailable;
          _isBLEAvailable = _transportService.isBLEAvailable;
          _isScanning = _transportService.isScanning;
        });
      }
    });
    
    // Initial state
    setState(() {
      _currentMode = _transportService.currentMode;
      _isInternetAvailable = _transportService.isInternetAvailable;
      _isBLEAvailable = _transportService.isBLEAvailable;
      _isScanning = _transportService.isScanning;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (widget.isCompact) {
      return _buildCompactIndicator(colorScheme);
    }
    
    return _buildFullIndicator(colorScheme);
  }
  
  Widget _buildCompactIndicator(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 16,
            color: _getStatusColor(),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFullIndicator(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                size: 24,
                color: _getStatusColor(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transport Status',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _getStatusText(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isScanning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Scanning',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          
          if (widget.showDetails) ...[
            const SizedBox(height: 16),
            _buildDetailRow('Internet', _isInternetAvailable),
            _buildDetailRow('Bluetooth', _isBLEAvailable),
            _buildDetailRow('Discovery', _isScanning ? 'Active' : 'Inactive'),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, dynamic value) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = value == true || value == 'Active';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value.toString(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (_currentMode) {
      case TransportMode.hybrid:
        return Colors.green;
      case TransportMode.internet:
        return Colors.blue;
      case TransportMode.ble:
        return Colors.orange;
      case TransportMode.offline:
        return Colors.red;
    }
  }
  
  IconData _getStatusIcon() {
    switch (_currentMode) {
      case TransportMode.hybrid:
        return Icons.wifi_tethering;
      case TransportMode.internet:
        return Icons.wifi;
      case TransportMode.ble:
        return Icons.bluetooth;
      case TransportMode.offline:
        return Icons.wifi_off;
    }
  }
  
  String _getStatusText() {
    switch (_currentMode) {
      case TransportMode.hybrid:
        return 'Hybrid Mode';
      case TransportMode.internet:
        return 'Internet Only';
      case TransportMode.ble:
        return 'BLE Only';
      case TransportMode.offline:
        return 'Offline';
    }
  }
}
