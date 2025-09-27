import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Removed unused legacy imports to align with PRD
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

class ConnectAccountsPage extends StatelessWidget {
  const ConnectAccountsPage({super.key});

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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.8),
                  scheme.tertiaryContainer.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Securely connect your accounts to power matching and alerts.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 16),
          _ConnectTile(
            icon: Icons.archive,
            title: 'LinkedIn GDPR Export',
            subtitle:
                'Import your connections ZIP/CSV on device (manual posts primary)',
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['csv', 'zip'],
              );
              if (result == null || result.files.isEmpty) return;
              final file = result.files.first;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              
              try {
                // Show loading state
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Uploading and parsing file...')),
                  );
                }
                
                final bytes = file.bytes ?? await _readFileBytesSafe(file.path);
                final ref = FirebaseStorage.instance
                    .ref('linkedin_uploads/$uid/${file.name}');
                await ref.putData(
                    bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
                
                // Call Cloud Function to parse the file
                final functions = FirebaseFunctions.instance;
                await functions.httpsCallable('linkedinCsvParser').call({
                  'filePath': 'linkedin_uploads/$uid/${file.name}',
                  'bucketName': 'serendipity-e0843.appspot.com',
                });
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Successfully parsed ${file.name}!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<dynamic> _readFileBytesSafe(String? path) async {
  if (path == null) {
    return Uint8List(0);
  }
  try {
    final file = File(path);
    return await file.readAsBytes();
  } catch (_) {
    return Uint8List(0);
  }
}

class _ConnectTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  const _ConnectTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                scheme.secondaryContainer.withValues(alpha: 0.8),
                scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer
                                .withValues(alpha: 0.9))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
