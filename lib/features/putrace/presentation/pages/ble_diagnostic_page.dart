import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/putrace_ble_service.dart';
import '../../../../core/services/putrace_ble_constants.dart';

class BleDiagnosticPage extends StatefulWidget {
  const BleDiagnosticPage({super.key});

  @override
  State<BleDiagnosticPage> createState() => _BleDiagnosticPageState();
}

class _BleDiagnosticPageState extends State<BleDiagnosticPage> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isScanning = false;
  late ColorScheme _colorScheme;
  
  final _bleService = GetIt.instance<PutraceBleService>();

  @override
  void initState() {
    super.initState();
    _setupBleListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = Theme.of(context).colorScheme;
  }

  void _setupBleListener() {
    _bleService.discoveryStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.insert(0, '${DateTime.now().toString().substring(11, 19)}: $log');
          if (_logs.length > 100) _logs.removeLast();
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    setState(() {
      _logs.insert(0, '🔐 Permission Check Results:');
      permissions.forEach((permission, status) {
        _logs.insert(1, '   ${permission.toString().split('.').last}: ${status.isGranted ? '✅' : '❌'}');
      });
    });
  }

  Future<void> _checkBluetoothStatus() async {
    setState(() {
      _logs.insert(0, '📱 Bluetooth Status Check:');
    });

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      _logs.insert(1, '   Supported: ${isSupported ? '✅' : '❌'}');

      if (isSupported) {
        final isOn = await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
        _logs.insert(2, '   Enabled: ${isOn ? '✅' : '❌'}');
      }
    } catch (e) {
      _logs.insert(1, '   Error: $e');
    }
  }

  Future<void> _startDiagnostic() async {
    setState(() {
      _logs.insert(0, '🚀 Starting BLE Diagnostic...');
      _isScanning = true;
    });

    try {
      await _bleService.startEventMode();
      setState(() {
        _logs.insert(1, '✅ BLE Event Mode Started');
      });
    } catch (e) {
      setState(() {
        _logs.insert(1, '❌ BLE Event Mode Failed: $e');
        _isScanning = false;
      });
    }
  }

  // Future<void> _stopDiagnostic() async {
  //   setState(() {
  //     _logs.insert(0, '⏹️ Stopping BLE Diagnostic...');
  //     _isScanning = false;
  //   });

  //   try {
  //     await _bleService.stopEventMode();
  //     setState(() {
  //       _logs.insert(1, '✅ BLE Event Mode Stopped');
  //     });
  //   } catch (e) {
  //     setState(() {
  //       _logs.insert(1, '❌ BLE Event Mode Stop Failed: $e');
  //     });
  //   }
  // }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bluetooth_searching, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              'BLE Diagnostic',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _colorScheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/putrace');
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          Expanded(child: _buildLogView()),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: _colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BLE Diagnostic Tools',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _checkPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Check Permissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorScheme.primary,
                    foregroundColor: _colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _checkBluetoothStatus,
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Check Bluetooth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorScheme.secondary,
                    foregroundColor: _colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startDiagnostic,
                  icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                  label: Text(_isScanning ? 'Stop' : 'Start Diagnostic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? _colorScheme.error : _colorScheme.tertiary,
                    foregroundColor: _colorScheme.onTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorScheme.outline,
                    foregroundColor: _colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service UUID:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  PutraceBleConstants.serviceUuid,
                                     style: TextStyle(
                     fontSize: 12,
                     fontFamily: 'Courier',
                     color: _colorScheme.onPrimaryContainer,
                   ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogView() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list, color: _colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Diagnostic Logs',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} entries',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: _colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs yet. Start the diagnostic to see BLE activity.',
                          style: GoogleFonts.inter(
                            color: _colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isError = log.contains('❌') || log.contains('⚠️');
                      final isSuccess = log.contains('✅');
                      final isInfo = log.contains('🔍') || log.contains('📡');
                      
                      Color textColor = _colorScheme.onSurface;
                      if (isError) textColor = _colorScheme.error;
                      if (isSuccess) textColor = _colorScheme.primary;
                      if (isInfo) textColor = _colorScheme.secondary;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                                                     style: TextStyle(
                             fontSize: 12,
                             fontFamily: 'Courier',
                             color: textColor,
                           ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
