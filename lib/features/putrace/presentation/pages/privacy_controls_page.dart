import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/putrace_settings_service.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyControlsPage extends StatefulWidget {
  const PrivacyControlsPage({super.key});

  @override
  State<PrivacyControlsPage> createState() => _PrivacyControlsPageState();
}

class _PrivacyControlsPageState extends State<PrivacyControlsPage> {
  bool presenceEnabled = true;
  double precisionKm = 5; // city-level default
  bool smsFallback = false;

  final _settings = GetIt.instance<PutraceSettingsService>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final presence = await _settings.isPresenceEnabled();
      final precision = await _settings.getPrecisionKm();
      final sms = await _settings.isSmsFallbackEnabled();
      if (!mounted) return;
      setState(() {
        presenceEnabled = presence;
        precisionKm = precision;
        smsFallback = sms;
      });
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.75),
                  scheme.secondaryContainer.withValues(alpha: 0.55),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Presence',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share Presence'),
                  subtitle:
                      const Text('Show city‑level presence to your contacts'),
                  value: presenceEnabled,
                  onChanged: (v) async {
                    setState(() => presenceEnabled = v);
                    await _settings.setPresenceEnabled(v);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Presence Precision'),
                  subtitle: Text('~${precisionKm.toStringAsFixed(0)} km'),
                  trailing: SizedBox(
                    width: 200,
                    child: Slider(
                      value: precisionKm,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      onChanged: (v) async {
                        setState(() => precisionKm = v);
                        await _settings.setPrecisionKm(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  scheme.tertiaryContainer.withValues(alpha: 0.7),
                  scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notifications',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('SMS Fallback'),
                  subtitle: const Text('Send alerts via SMS when offline'),
                  value: smsFallback,
                  onChanged: (v) async {
                    setState(() => smsFallback = v);
                    await _settings.setSmsFallbackEnabled(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  scheme.secondaryContainer.withValues(alpha: 0.7),
                  scheme.primaryContainer.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data & Controls',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pause Presence'),
                  subtitle: const Text('Temporarily stop sharing presence'),
                  trailing: FilledButton.tonal(
                      onPressed: () {}, child: const Text('Pause for 24h')),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                        onPressed: () {}, child: const Text('Export')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: () {}, child: const Text('Delete')),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
