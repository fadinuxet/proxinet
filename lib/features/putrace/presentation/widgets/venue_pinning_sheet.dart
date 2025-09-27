import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../data/services/osm_venue_service.dart';

class VenuePinningSheet extends StatefulWidget {
  final latlong.LatLng position;
  final Function(VenueData) onVenueCreated;
  final List<OSMVenue>? existingVenues;

  const VenuePinningSheet({
    super.key,
    required this.position,
    required this.onVenueCreated,
    this.existingVenues,
  });

  @override
  State<VenuePinningSheet> createState() => _VenuePinningSheetState();
}

class _VenuePinningSheetState extends State<VenuePinningSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'Coffee Shop';
  String _selectedCategory = 'Professional';
  bool _isPublic = true;

  final List<String> _venueTypes = [
    'Coffee Shop',
    'Restaurant',
    'Co-Working Space',
    'Conference Center',
    'Library',
    'Gym',
    'Park',
    'Other',
  ];

  final List<String> _categories = [
    'Professional',
    'Social',
    'Educational',
    'Fitness',
    'Entertainment',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_location,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pin New Venue',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Add a networking venue to the map',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Existing venues nearby
          if (widget.existingVenues != null && widget.existingVenues!.isNotEmpty) ...[
            _buildExistingVenuesSection(),
            const SizedBox(height: 24),
          ],
          
          // Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Venue name
                _buildTextField(
                  controller: _nameController,
                  label: 'Venue Name',
                  hint: 'e.g., Starbucks Downtown',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a venue name';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Venue type
                _buildDropdown(
                  label: 'Venue Type',
                  value: _selectedType,
                  items: _venueTypes,
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                
                const SizedBox(height: 16),
                
                // Category
                _buildDropdown(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Describe this venue for networking...',
                  maxLines: 3,
                ),
                
                const SizedBox(height: 16),
                
                // Privacy settings
                _buildPrivacySettings(),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _createVenue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Pin Venue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingVenuesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Nearby Venues Found',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We found ${widget.existingVenues!.length} venues nearby. Consider using one of these instead of creating a new one.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 12),
          ...widget.existingVenues!.take(3).map((venue) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _selectExistingVenue(venue),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getVenueIcon(venue.type),
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venue.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${venue.type} • ${venue.networkingScore.toStringAsFixed(1)}★',
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy Settings',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value ?? true),
            ),
            Expanded(
              child: Text(
                'Make this venue public for other users to discover',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _selectExistingVenue(OSMVenue venue) {
    // Convert existing venue to VenueData and create it
    final venueData = VenueData(
      name: venue.name,
      type: venue.type,
      category: 'Professional', // Default category
      description: venue.address ?? 'Discovered venue',
      location: venue.location,
      isPublic: true,
      isUserCreated: false,
      googlePlaceId: venue.id,
    );
    
    widget.onVenueCreated(venueData);
    Navigator.pop(context);
  }

  void _createVenue() {
    if (_formKey.currentState!.validate()) {
      final venueData = VenueData(
        name: _nameController.text,
        type: _selectedType,
        category: _selectedCategory,
        description: _descriptionController.text,
        location: widget.position,
        isPublic: _isPublic,
        isUserCreated: true,
      );
      
      widget.onVenueCreated(venueData);
      Navigator.pop(context);
    }
  }

  IconData _getVenueIcon(String type) {
    switch (type) {
      case 'Coffee Shop':
        return Icons.local_cafe;
      case 'Restaurant':
        return Icons.restaurant;
      case 'Co-Working Space':
        return Icons.work;
      case 'Conference Center':
        return Icons.business;
      case 'Library':
        return Icons.local_library;
      case 'Gym':
        return Icons.fitness_center;
      case 'Park':
        return Icons.park;
      default:
        return Icons.location_on;
    }
  }
}

/// Venue data model for user-created venues
class VenueData {
  final String name;
  final String type;
  final String category;
  final String description;
  final latlong.LatLng location;
  final bool isPublic;
  final bool isUserCreated;
  final String? googlePlaceId;

  VenueData({
    required this.name,
    required this.type,
    required this.category,
    required this.description,
    required this.location,
    required this.isPublic,
    required this.isUserCreated,
    this.googlePlaceId,
  });
}
