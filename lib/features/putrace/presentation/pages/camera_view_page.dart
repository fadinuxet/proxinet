import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/putrace_design.dart';
import '../../../../core/services/putrace_ble_service.dart';
import 'package:google_fonts/google_fonts.dart';

class CameraViewPage extends StatefulWidget {
  const CameraViewPage({super.key});

  @override
  State<CameraViewPage> createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  final _ble = GetIt.instance<PutraceBleService>();
  bool _running = false;
  final List<String> _events = [];

  @override
  void initState() {
    super.initState();
    _ble.discoveryStream.listen((e) {
      if (!mounted) return;
      setState(() => _events.insert(0, e));
    });
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
      ),
      body: Column(
        children: [
          // Explanation Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.8),
                  scheme.secondaryContainer.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: scheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'What is Event Mode?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Event Mode uses Bluetooth Low Energy (BLE) to discover other Putrace users nearby. This is perfect for:\n\n'
                  '• Networking events and conferences\n'
                  '• Meetups and social gatherings\n'
                  '• Finding colleagues at work\n'
                  '• Discovering people with similar interests\n\n'
                  'Your device will broadcast a temporary identifier that other users can discover, and you\'ll see nearby Putrace users in real-time.',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Controls Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    GradientButton(
                      onPressed: _running
                          ? null
                          : () async {
                              await _ble.startEventMode();
                              setState(() => _running = true);
                            },
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      borderRadius: BorderRadius.circular(10),
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _running
                          ? () async {
                              await _ble.stopEventMode();
                              setState(() => _running = false);
                            }
                          : null,
                      child: const Text('Stop'),
                    ),
                    const SizedBox(width: 8),
                    if (_events.isNotEmpty)
                      Text('Events: ${_events.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                // Status message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _running
                              ? 'Event Mode is active. Scanning for nearby users...'
                              : 'Click Start to begin discovering nearby Putrace users',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: PutraceDesign.cardGradient(scheme),
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Text(_events[i]),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
