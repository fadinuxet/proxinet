enum UserTier {
  anonymous,  // FREE (Anonymous) - No signup required
  standard,   // Standard (Free) - Free signup
  premium     // Premium (Paid) - Subscription
}

extension UserTierExtension on UserTier {
  String get displayName {
    switch (this) {
      case UserTier.anonymous:
        return 'FREE (Anonymous)';
      case UserTier.standard:
        return 'Standard';
      case UserTier.premium:
        return 'Premium';
    }
  }
  
  String get description {
    switch (this) {
      case UserTier.anonymous:
        return 'Anonymous discovery with BLE only';
      case UserTier.standard:
        return 'Full features with data persistence';
      case UserTier.premium:
        return 'Advanced features and priority access';
    }
  }
  
  bool get isAnonymous => this == UserTier.anonymous;
  bool get isStandard => this == UserTier.standard;
  bool get isPremium => this == UserTier.premium;
  
  bool get canMessage => !isAnonymous;
  bool get canSaveConnections => !isAnonymous;
  bool get canUseLocationMode => !isAnonymous;
  bool get canUseVirtualMode => isPremium;
  bool get canUseLinkedInIntegration => !isAnonymous;
  bool get canUseAdvancedFeatures => isPremium;
}
