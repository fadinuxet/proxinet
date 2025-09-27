import 'package:flutter/material.dart';
import 'package:putrace/core/services/simple_firebase_monitor.dart';

class SimpleMonitoringDashboard extends StatefulWidget {
  const SimpleMonitoringDashboard({super.key});

  @override
  State<SimpleMonitoringDashboard> createState() => _SimpleMonitoringDashboardState();
}

class _SimpleMonitoringDashboardState extends State<SimpleMonitoringDashboard> {
  Map<String, dynamic>? _monitoringData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonitoringData();
  }

  Future<void> _loadMonitoringData() async {
    setState(() => _isLoading = true);
    
    try {
      final data = SimpleFirebaseMonitor.getUsageStats();
      final deviceInfo = await SimpleFirebaseMonitor.getDeviceInfo();
      
      setState(() {
        _monitoringData = {
          'cost_monitoring': data,
          'device_info': deviceInfo,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading monitoring data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Monitoring Dashboard'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonitoringData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monitoringData == null
              ? const Center(child: Text('No monitoring data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCostMonitoringCard(),
                      const SizedBox(height: 16),
                      _buildDeviceInfoCard(),
                      const SizedBox(height: 16),
                      _buildActionsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCostMonitoringCard() {
    final costData = _monitoringData!['cost_monitoring'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Cost Monitoring',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Daily Reads', '${costData['dailyReads']}', '${costData['readLimit']}'),
            _buildMetricRow('Daily Writes', '${costData['dailyWrites']}', '${costData['writeLimit']}'),
            _buildMetricRow('Daily Deletes', '${costData['dailyDeletes']}', '${costData['deleteLimit']}'),
            const SizedBox(height: 8),
            _buildPercentageBar('Reads', double.parse(costData['readPercentage'])),
            _buildPercentageBar('Writes', double.parse(costData['writePercentage'])),
            _buildPercentageBar('Deletes', double.parse(costData['deletePercentage'])),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final deviceData = _monitoringData!['device_info'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Device Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Platform', deviceData['platform'], ''),
            _buildMetricRow('Version', deviceData['version'], ''),
            _buildMetricRow('Model', deviceData['model'], ''),
            _buildMetricRow('Manufacturer', deviceData['manufacturer'] ?? 'N/A', ''),
            _buildMetricRow('Low End Device', deviceData['isLowEnd'] ? 'Yes' : 'No', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SimpleFirebaseMonitor.trackPutraceEvent('test_event', {
                        'test': true,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test event tracked')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Test Event'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadMonitoringData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SimpleFirebaseMonitor.trackBLEEvent('test_scan', {
                        'devices_found': 3,
                        'scan_duration_ms': 30000,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('BLE test event tracked')),
                      );
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Test BLE'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SimpleFirebaseMonitor.trackLocationEvent('test_location', {
                        'accuracy_meters': 10.5,
                        'response_time_ms': 2000,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location test event tracked')),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Test Location'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String limit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text('$value${limit.isNotEmpty ? ' / $limit' : ''}'),
        ],
      ),
    );
  }

  Widget _buildPercentageBar(String label, double percentage) {
    Color color = Colors.green;
    if (percentage > 80) {
      color = Colors.red;
    } else if (percentage > 60) {
      color = Colors.orange;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${percentage.toStringAsFixed(1)}%'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }
}
