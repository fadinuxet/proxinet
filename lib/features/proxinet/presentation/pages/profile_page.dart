import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  String? _avatarUrl;
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _setupAutoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _companyController.removeListener(_onFieldChanged);
    _titleController.removeListener(_onFieldChanged);
    _locationController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _bioController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _setupAutoSave() {
    // Add listeners to all text controllers for auto-save
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _titleController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_isEditing) return; // Only auto-save when in editing mode

    _hasUnsavedChanges = true;

    // Cancel previous timer
    _autoSaveTimer?.cancel();

    // Set new timer for 2 seconds delay
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_hasUnsavedChanges) {
        _autoSave();
      }
    });
  }

  Future<void> _autoSave() async {
    if (!_hasUnsavedChanges || !_isEditing) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('Auto-saving profile...');

      final profileRef =
          FirebaseFirestore.instance.collection('profiles').doc(user.uid);

      final profileDoc = await profileRef.get();

      if (profileDoc.exists) {
        await profileRef.update({
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'company': _companyController.text.trim(),
          'title': _titleController.text.trim(),
          'location': _locationController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await profileRef.set({
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'company': _companyController.text.trim(),
          'title': _titleController.text.trim(),
          'location': _locationController.text.trim(),
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _hasUnsavedChanges = false;
      print('Profile auto-saved successfully');

      // Show subtle success indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved automatically'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(8),
          ),
        );
      }
    } catch (e) {
      print('Auto-save error: $e');
      // Don't show error for auto-save to avoid being annoying
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return;
    }

    print('Loading profile for user: ${user.uid}');
    setState(() {
      _isLoading = true;
    });

    try {
      // First, try to get the existing profile
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        print('Profile found, loading data');
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _companyController.text = data['company'] ?? '';
        _titleController.text = data['title'] ?? '';
        _locationController.text = data['location'] ?? '';
        _avatarUrl = data['avatarUrl'];
      } else {
        print('Profile not found, creating new one');
        // Create a new profile document
        try {
          final profileData = {
            'name': user.displayName ?? 'New User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          print('Creating profile with data: $profileData');
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .set(profileData);

          print('Profile created successfully');

          // Set default values from Firebase Auth
          _nameController.text = user.displayName ?? 'New User';
          _avatarUrl = user.photoURL;
        } catch (createError) {
          print('Error creating profile: $createError');
          // Set default values anyway and continue
          _nameController.text = user.displayName ?? 'New User';
          _avatarUrl = user.photoURL;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Profile created with default values. Some features may be limited.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      print('Profile loaded successfully');
    } catch (e) {
      print('Error loading profile: $e');

      // Set default values from Firebase Auth as fallback
      _nameController.text = user.displayName ?? 'New User';
      _avatarUrl = user.photoURL;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using default profile data. Error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      // Check if user is authenticated first
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }

      print('User authenticated: ${user.uid}');

      // Check storage permissions first
      try {
        // Request storage permission with better error handling
        final status = await Permission.storage.request();
        if (status != PermissionStatus.granted) {
          // Try requesting photos permission as fallback (Android 13+)
          final photosStatus = await Permission.photos.request();
          if (photosStatus != PermissionStatus.granted) {
            throw Exception(
                'Storage permission denied. Please grant storage access in settings.');
          }
        }
      } catch (permError) {
        print('Permission error: $permError');
        // Continue anyway - some devices don't require explicit permission
      }

      // Pick image from gallery
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      print('Image selected: ${image.path}');
      setState(() => _isLoading = true);

      try {
        // Read image bytes
        final bytes = await image.readAsBytes();
        // Validate file size (max 5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          throw Exception(
              'Image too large. Please select an image smaller than 5MB.');
        }

        final fileName =
            '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref('avatars/$fileName');

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = ref.putData(bytes, metadata);
        uploadTask.snapshotEvents.listen((snapshot) {
          print(
              'Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
        });
        await uploadTask; // Wait for upload to complete

        final url = await ref.getDownloadURL();
        setState(() => _avatarUrl = url);

        final profileRef =
            FirebaseFirestore.instance.collection('profiles').doc(user.uid);
        final profileDoc = await profileRef.get();

        if (profileDoc.exists) {
          await profileRef.update(
              {'avatarUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
        } else {
          await profileRef.set({
            'avatarUrl': url,
            'name': user.displayName ?? 'New User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        _hasUnsavedChanges = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (uploadError) {
        print('Upload error: $uploadError');
        String errorMessage = 'Failed to update avatar';
        if (uploadError.toString().contains('permission')) {
          errorMessage =
              'Storage permission required. Please grant access in settings.';
        } else if (uploadError.toString().contains('too large')) {
          errorMessage = 'Image too large. Please select a smaller image.';
        } else if (uploadError.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (uploadError.toString().contains('timeout')) {
          errorMessage = 'Upload timed out. Please try again.';
        } else if (uploadError.toString().contains('unauthorized')) {
          errorMessage = 'Authentication error. Please sign in again.';
        } else {
          errorMessage = 'Error updating avatar: $uploadError';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _pickAvatar(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Avatar upload error: $e');
      if (mounted) {
        String errorMessage = 'Failed to update avatar';
        if (e.toString().contains('permission')) {
          errorMessage =
              'Permission required. Please grant access in settings.';
        } else if (e.toString().contains('not authenticated')) {
          errorMessage = 'Please sign in again.';
        } else {
          errorMessage = 'Error updating avatar: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _pickAvatar(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Removed manual save method - now using auto-save
  // The _autoSave() method handles all profile updates automatically

  Future<void> _setCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      // Check location permission with better error handling
      final locationPermission = await Permission.locationWhenInUse.request();
      if (locationPermission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location permission is required to set your current location'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Check if location services are enabled
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Please enable location services in your device settings'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Create a readable location string from coordinates
      final lat = position.latitude;
      final lng = position.longitude;

      // Format coordinates in a user-friendly way
      String locationText = '';
      if (lat.abs() < 1) {
        // Very small coordinates, show more decimal places
        locationText = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      } else if (lat.abs() < 10) {
        // Small coordinates, show 4 decimal places
        locationText = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      } else {
        // Larger coordinates, show 3 decimal places
        locationText = '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
      }

      // Update the location field
      setState(() {
        _locationController.text = locationText;
      });

      // Trigger auto-save for location change
      _onFieldChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set to: $locationText'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        String errorMessage = 'Failed to get current location';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Location request timed out. Please try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage =
              'Location permission denied. Please grant location access.';
        } else if (e.toString().contains('location service')) {
          errorMessage = 'Location services are disabled. Please enable them.';
        } else {
          errorMessage = 'Error: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _setCurrentLocation,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Always show profile even if loading failed
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Please sign in to view your profile'),
        ),
      );
    }

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
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing) ...[
            // Auto-save status indicator
            if (_hasUnsavedChanges)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Saving...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Saved',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            // Done button
            TextButton(
              onPressed: () {
                setState(() => _isEditing = false);
                _hasUnsavedChanges = false;
                _autoSaveTimer?.cancel();
              },
              child: const Text('Done'),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withOpacity(0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _avatarUrl != null
                            ? Image.network(
                                _avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultAvatar(scheme),
                              )
                            : _buildDefaultAvatar(scheme),
                      ),
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: _pickAvatar,
                            borderRadius: BorderRadius.circular(20),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Profile Form
              if (_isEditing) ...[
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: TextEditingController(
                    text:
                        FirebaseAuth.instance.currentUser?.email ?? 'No email',
                  ),
                  label: 'Email',
                  icon: Icons.email,
                  enabled: false,
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _bioController,
                  label: 'Bio',
                  icon: Icons.info,
                  maxLines: 3,
                  hint: 'Tell people about yourself...',
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _companyController,
                  label: 'Company',
                  icon: Icons.business,
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _titleController,
                  label: 'Job Title',
                  icon: Icons.work,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        icon: Icons.location_on,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _isLoading ? null : _setCurrentLocation,
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 24),
                      tooltip: 'Set Current Location',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Auto-save info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your profile saves automatically as you type',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Display Mode
                _buildProfileInfo('Name', _nameController.text, Icons.person),
                const SizedBox(height: 16),
                _buildProfileInfo(
                    'Email',
                    FirebaseAuth.instance.currentUser?.email ?? 'No email',
                    Icons.email),
                const SizedBox(height: 16),
                if (_bioController.text.isNotEmpty) ...[
                  _buildProfileInfo('Bio', _bioController.text, Icons.info),
                  const SizedBox(height: 16),
                ],
                if (_companyController.text.isNotEmpty) ...[
                  _buildProfileInfo(
                      'Company', _companyController.text, Icons.business),
                  const SizedBox(height: 16),
                ],
                if (_titleController.text.isNotEmpty) ...[
                  _buildProfileInfo(
                      'Job Title', _titleController.text, Icons.work),
                  const SizedBox(height: 16),
                ],
                if (_locationController.text.isNotEmpty) ...[
                  _buildProfileInfo(
                      'Location', _locationController.text, Icons.location_on),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit, size: 20),
                    label: const Text('Edit Profile'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: scheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildProfileInfo(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(ColorScheme scheme) {
    return Container(
      color: scheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: 60,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}
