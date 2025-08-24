import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String? bio;
  final String? company;
  final String? title;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? industry;
  final List<String> skills;
  final List<String> interests;
  final List<String> networkingGoals;
  final String? avatarUrl;
  final String? linkedinUrl;
  final String? websiteUrl;
  final String? phoneNumber;
  final ProfessionalBackground professionalBackground;
  final List<String> certifications;
  final List<String> languages;
  final List<String> seekingConnections;
  final ProfileVisibility visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAvailable;
  final String? availabilityMessage;
  final List<String> preferredMeetingTypes;
  final List<String> preferredMeetingLocations;

  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.bio,
    this.company,
    this.title,
    this.location,
    this.latitude,
    this.longitude,
    this.industry,
    this.skills = const [],
    this.interests = const [],
    this.networkingGoals = const [],
    this.avatarUrl,
    this.linkedinUrl,
    this.websiteUrl,
    this.phoneNumber,
    this.professionalBackground = const ProfessionalBackground(),
    this.certifications = const [],
    this.languages = const [],
    this.seekingConnections = const [],
    this.visibility = const ProfileVisibility(),
    required this.createdAt,
    required this.updatedAt,
    this.isAvailable = false,
    this.availabilityMessage,
    this.preferredMeetingTypes = const [],
    this.preferredMeetingLocations = const [],
  });

  // Factory constructor from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserProfile(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      bio: data['bio'],
      company: data['company'],
      title: data['title'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      industry: data['industry'],
      skills: List<String>.from(data['skills'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      networkingGoals: List<String>.from(data['networkingGoals'] ?? []),
      avatarUrl: data['avatarUrl'],
      linkedinUrl: data['linkedinUrl'],
      websiteUrl: data['websiteUrl'],
      phoneNumber: data['phoneNumber'],
      professionalBackground: ProfessionalBackground.fromMap(data['professionalBackground'] ?? {}),
      certifications: List<String>.from(data['certifications'] ?? []),
      languages: List<String>.from(data['languages'] ?? []),
      seekingConnections: List<String>.from(data['seekingConnections'] ?? []),
      visibility: ProfileVisibility.fromMap(data['visibility'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isAvailable: data['isAvailable'] ?? false,
      availabilityMessage: data['availabilityMessage'],
      preferredMeetingTypes: List<String>.from(data['preferredMeetingTypes'] ?? []),
      preferredMeetingLocations: List<String>.from(data['preferredMeetingLocations'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'bio': bio,
      'company': company,
      'title': title,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'industry': industry,
      'skills': skills,
      'interests': interests,
      'networkingGoals': networkingGoals,
      'avatarUrl': avatarUrl,
      'linkedinUrl': linkedinUrl,
      'websiteUrl': websiteUrl,
      'phoneNumber': phoneNumber,
      'professionalBackground': professionalBackground.toMap(),
      'certifications': certifications,
      'languages': languages,
      'seekingConnections': seekingConnections,
      'visibility': visibility.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isAvailable': isAvailable,
      'availabilityMessage': availabilityMessage,
      'preferredMeetingTypes': preferredMeetingTypes,
      'preferredMeetingLocations': preferredMeetingLocations,
    };
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? bio,
    String? company,
    String? title,
    String? location,
    String? industry,
    List<String>? skills,
    List<String>? interests,
    List<String>? networkingGoals,
    String? avatarUrl,
    String? linkedinUrl,
    String? websiteUrl,
    String? phoneNumber,
    ProfessionalBackground? professionalBackground,
    List<String>? certifications,
    List<String>? languages,
    List<String>? seekingConnections,
    ProfileVisibility? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAvailable,
    String? availabilityMessage,
    List<String>? preferredMeetingTypes,
    List<String>? preferredMeetingLocations,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      company: company ?? this.company,
      title: title ?? this.title,
      location: location ?? this.location,
      industry: industry ?? this.industry,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      networkingGoals: networkingGoals ?? this.networkingGoals,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      professionalBackground: professionalBackground ?? this.professionalBackground,
      certifications: certifications ?? this.certifications,
      languages: languages ?? this.languages,
      seekingConnections: seekingConnections ?? this.seekingConnections,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAvailable: isAvailable ?? this.isAvailable,
      availabilityMessage: availabilityMessage ?? this.availabilityMessage,
      preferredMeetingTypes: preferredMeetingTypes ?? this.preferredMeetingTypes,
      preferredMeetingLocations: preferredMeetingLocations ?? this.preferredMeetingLocations,
    );
  }

  // Get display name (company + title or just name)
  String get displayName {
    if (company != null && title != null) {
      return '$title at $company';
    } else if (title != null) {
      return title!;
    } else if (company != null) {
      return company!;
    }
    return name;
  }

  // Get short bio (truncated)
  String get shortBio {
    if (bio == null || bio!.isEmpty) return '';
    if (bio!.length <= 100) return bio!;
    return '${bio!.substring(0, 100)}...';
  }

  // Check if profile is complete
  bool get isProfileComplete {
    return name.isNotEmpty && 
           (bio != null && bio!.isNotEmpty) &&
           (company != null && company!.isNotEmpty) &&
           (title != null && title!.isNotEmpty) &&
           skills.isNotEmpty;
  }

  // Get profile completion percentage
  double get profileCompletionPercentage {
    int completedFields = 0;
    int totalFields = 8; // name, bio, company, title, skills, interests, networkingGoals, avatar
    
    if (name.isNotEmpty) completedFields++;
    if (bio != null && bio!.isNotEmpty) completedFields++;
    if (company != null && company!.isNotEmpty) completedFields++;
    if (title != null && title!.isNotEmpty) completedFields++;
    if (skills.isNotEmpty) completedFields++;
    if (interests.isNotEmpty) completedFields++;
    if (networkingGoals.isNotEmpty) completedFields++;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) completedFields++;
    
    return completedFields / totalFields;
  }
}

class ProfessionalBackground {
  final String? education;
  final String? experience;
  final List<String> achievements;
  final List<String> publications;
  final List<String> patents;
  final List<String> awards;
  final String? yearsOfExperience;

  const ProfessionalBackground({
    this.education,
    this.experience,
    this.achievements = const [],
    this.publications = const [],
    this.patents = const [],
    this.awards = const [],
    this.yearsOfExperience,
  });

  factory ProfessionalBackground.fromMap(Map<String, dynamic> map) {
    return ProfessionalBackground(
      education: map['education'],
      experience: map['experience'],
      achievements: List<String>.from(map['achievements'] ?? []),
      publications: List<String>.from(map['publications'] ?? []),
      patents: List<String>.from(map['patents'] ?? []),
      awards: List<String>.from(map['awards'] ?? []),
      yearsOfExperience: map['yearsOfExperience'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'education': education,
      'experience': experience,
      'achievements': achievements,
      'publications': publications,
      'patents': patents,
      'awards': awards,
      'yearsOfExperience': yearsOfExperience,
    };
  }
}

class ProfileVisibility {
  final bool showEmail;
  final bool showPhone;
  final bool showLocation;
  final bool showCompany;
  final bool showSkills;
  final bool showInterests;
  final bool showNetworkingGoals;
  final bool showProfessionalBackground;
  final bool showAvailability;
  final List<String> visibleToConnections;
  final List<String> visibleToPublic;

  const ProfileVisibility({
    this.showEmail = true,
    this.showPhone = false,
    this.showLocation = true,
    this.showCompany = true,
    this.showSkills = true,
    this.showInterests = true,
    this.showNetworkingGoals = true,
    this.showProfessionalBackground = true,
    this.showAvailability = true,
    this.visibleToConnections = const [],
    this.visibleToPublic = const [],
  });

  factory ProfileVisibility.fromMap(Map<String, dynamic> map) {
    return ProfileVisibility(
      showEmail: map['showEmail'] ?? true,
      showPhone: map['showPhone'] ?? false,
      showLocation: map['showLocation'] ?? true,
      showCompany: map['showCompany'] ?? true,
      showSkills: map['showSkills'] ?? true,
      showInterests: map['showInterests'] ?? true,
      showNetworkingGoals: map['showNetworkingGoals'] ?? true,
      showProfessionalBackground: map['showProfessionalBackground'] ?? true,
      showAvailability: map['showAvailability'] ?? true,
      visibleToConnections: List<String>.from(map['visibleToConnections'] ?? []),
      visibleToPublic: List<String>.from(map['visibleToPublic'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showEmail': showEmail,
      'showPhone': showPhone,
      'showLocation': showLocation,
      'showCompany': showCompany,
      'showSkills': showSkills,
      'showInterests': showInterests,
      'showNetworkingGoals': showNetworkingGoals,
      'showProfessionalBackground': showProfessionalBackground,
      'showAvailability': showAvailability,
      'visibleToConnections': visibleToConnections,
      'visibleToPublic': visibleToPublic,
    };
  }
}
