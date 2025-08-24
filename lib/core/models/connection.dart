import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus {
  pending,
  accepted,
  rejected,
  blocked,
  removed
}

enum ConnectionType {
  professional,
  mentor,
  mentee,
  colleague,
  friend,
  investor,
  entrepreneur
}

class Connection {
  final String id;
  final String requesterId;
  final String receiverId;
  final ConnectionStatus status;
  final ConnectionType type;
  final String? message;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final List<String> sharedInterests;
  final List<String> sharedSkills;
  final bool isMutual;
  final int interactionCount;
  final DateTime? lastInteractionAt;
  final String? meetingNotes;
  final List<String> tags;
  final bool isFavorite;

  const Connection({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    this.status = ConnectionStatus.pending,
    this.type = ConnectionType.professional,
    this.message,
    required this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.sharedInterests = const [],
    this.sharedSkills = const [],
    this.isMutual = false,
    this.interactionCount = 0,
    this.lastInteractionAt,
    this.meetingNotes,
    this.tags = const [],
    this.isFavorite = false,
  });

  // Factory constructor from Firestore document
  factory Connection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Connection(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      status: ConnectionStatus.values.firstWhere(
        (e) => e.toString() == 'ConnectionStatus.${data['status']}',
        orElse: () => ConnectionStatus.pending,
      ),
      type: ConnectionType.values.firstWhere(
        (e) => e.toString() == 'ConnectionType.${data['type']}',
        orElse: () => ConnectionType.professional,
      ),
      message: data['message'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      acceptedAt: data['acceptedAt'] != null ? (data['acceptedAt'] as Timestamp).toDate() : null,
      sharedInterests: List<String>.from(data['sharedInterests'] ?? []),
      sharedSkills: List<String>.from(data['sharedSkills'] ?? []),
      isMutual: data['isMutual'] ?? false,
      interactionCount: data['interactionCount'] ?? 0,
      lastInteractionAt: data['lastInteractionAt'] != null ? (data['lastInteractionAt'] as Timestamp).toDate() : null,
      meetingNotes: data['meetingNotes'],
      tags: List<String>.from(data['tags'] ?? []),
      isFavorite: data['isFavorite'] ?? false,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'receiverId': receiverId,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'sharedInterests': sharedInterests,
      'sharedSkills': sharedSkills,
      'isMutual': isMutual,
      'interactionCount': interactionCount,
      'lastInteractionAt': lastInteractionAt != null ? Timestamp.fromDate(lastInteractionAt!) : null,
      'meetingNotes': meetingNotes,
      'tags': tags,
      'isFavorite': isFavorite,
    };
  }

  // Create a copy with updated fields
  Connection copyWith({
    String? id,
    String? requesterId,
    String? receiverId,
    ConnectionStatus? status,
    ConnectionType? type,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    List<String>? sharedInterests,
    List<String>? sharedSkills,
    bool? isMutual,
    int? interactionCount,
    DateTime? lastInteractionAt,
    String? meetingNotes,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return Connection(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      type: type ?? this.type,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      sharedInterests: sharedInterests ?? this.sharedInterests,
      sharedSkills: sharedSkills ?? this.sharedSkills,
      isMutual: isMutual ?? this.isMutual,
      interactionCount: interactionCount ?? this.interactionCount,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      meetingNotes: meetingNotes ?? this.meetingNotes,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Check if connection is active
  bool get isActive => status == ConnectionStatus.accepted;

  // Check if connection is pending
  bool get isPending => status == ConnectionStatus.pending;

  // Check if connection is rejected
  bool get isRejected => status == ConnectionStatus.rejected;

  // Check if connection is blocked
  bool get isBlocked => status == ConnectionStatus.blocked;

  // Get connection age
  Duration get age => DateTime.now().difference(createdAt);

  // Get connection age in days
  int get ageInDays => age.inDays;

  // Get connection age in weeks
  int get ageInWeeks => age.inDays ~/ 7;

  // Get connection age in months
  int get ageInMonths => age.inDays ~/ 30;

  // Get connection age in years
  int get ageInYears => age.inDays ~/ 365;

  // Get formatted age string
  String get formattedAge {
    if (ageInYears > 0) {
      return '$ageInYears year${ageInYears > 1 ? 's' : ''}';
    } else if (ageInMonths > 0) {
      return '$ageInMonths month${ageInMonths > 1 ? 's' : ''}';
    } else if (ageInWeeks > 0) {
      return '$ageInWeeks week${ageInWeeks > 1 ? 's' : ''}';
    } else if (ageInDays > 0) {
      return '$ageInDays day${ageInDays > 1 ? 's' : ''}';
    } else {
      return 'Today';
    }
  }

  // Get status display text
  String get statusDisplayText {
    switch (status) {
      case ConnectionStatus.pending:
        return 'Pending';
      case ConnectionStatus.accepted:
        return 'Connected';
      case ConnectionStatus.rejected:
        return 'Rejected';
      case ConnectionStatus.blocked:
        return 'Blocked';
      case ConnectionStatus.removed:
        return 'Removed';
    }
  }

  // Get type display text
  String get typeDisplayText {
    switch (type) {
      case ConnectionType.professional:
        return 'Professional';
      case ConnectionType.mentor:
        return 'Mentor';
      case ConnectionType.mentee:
        return 'Mentee';
      case ConnectionType.colleague:
        return 'Colleague';
      case ConnectionType.friend:
        return 'Friend';
      case ConnectionType.investor:
        return 'Investor';
      case ConnectionType.entrepreneur:
        return 'Entrepreneur';
    }
  }
}

class ConnectionRequest {
  final String id;
  final String requesterId;
  final String receiverId;
  final String message;
  final ConnectionType type;
  final List<String> sharedInterests;
  final List<String> sharedSkills;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const ConnectionRequest({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.message,
    this.type = ConnectionType.professional,
    this.sharedInterests = const [],
    this.sharedSkills = const [],
    required this.createdAt,
    this.isRead = false,
    this.readAt,
  });

  // Factory constructor from Firestore document
  factory ConnectionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConnectionRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      type: ConnectionType.values.firstWhere(
        (e) => e.toString() == 'ConnectionType.${data['type']}',
        orElse: () => ConnectionType.professional,
      ),
      sharedInterests: List<String>.from(data['sharedInterests'] ?? []),
      sharedSkills: List<String>.from(data['sharedSkills'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'receiverId': receiverId,
      'message': message,
      'type': type.toString().split('.').last,
      'sharedInterests': sharedInterests,
      'sharedSkills': sharedSkills,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  // Get request age
  Duration get age => DateTime.now().difference(createdAt);

  // Get request age in days
  int get ageInDays => age.inDays;

  // Get formatted age string
  String get formattedAge {
    if (ageInDays > 0) {
      return '$ageInDays day${ageInDays > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }
}
