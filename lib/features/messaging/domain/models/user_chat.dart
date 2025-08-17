class UserChat {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? lastSeen;
  final bool isOnline;
  final String? status;

  const UserChat({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.lastSeen,
    this.isOnline = false,
    this.status,
  });

  factory UserChat.fromJson(Map<String, dynamic> json) {
    return UserChat(
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      lastSeen: json['lastSeen'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'lastSeen': lastSeen,
      'isOnline': isOnline,
      'status': status,
    };
  }

  UserChat copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
    String? lastSeen,
    bool? isOnline,
    String? status,
  }) {
    return UserChat(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
    );
  }
}
