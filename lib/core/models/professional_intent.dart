enum ProfessionalIntentType {
  quickAdvice,
  technicalCollaboration,
  industryInsights,
  mentorship,
  networking,
  projectPartnership,
  jobOpportunity,
  investmentDiscussion,
  knowledgeSharing,
  eventConnection,
}

class ProfessionalIntent {
  final ProfessionalIntentType type;
  final String title;
  final String description;
  final Duration estimatedDuration;
  final List<String> relevantSkills;
  final List<String> idealFor;
  final bool requiresPremium;

  const ProfessionalIntent({
    required this.type,
    required this.title,
    required this.description,
    required this.estimatedDuration,
    required this.relevantSkills,
    required this.idealFor,
    this.requiresPremium = false,
  });

  static const List<ProfessionalIntent> availableIntents = [
    ProfessionalIntent(
      type: ProfessionalIntentType.quickAdvice,
      title: '15min Professional Advice',
      description: 'Quick industry or technical guidance',
      estimatedDuration: Duration(minutes: 15),
      relevantSkills: ['mentoring', 'expert_advice', 'industry_knowledge'],
      idealFor: ['career_guidance', 'technical_questions', 'industry_insights'],
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.technicalCollaboration,
      title: 'Technical Collaboration',
      description: 'Deep technical discussion and problem-solving',
      estimatedDuration: Duration(minutes: 30),
      relevantSkills: ['problem_solving', 'architecture', 'development'],
      idealFor: ['technical_challenges', 'system_design', 'code_review'],
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.industryInsights,
      title: 'Industry Insights Exchange',
      description: 'Share and discuss industry trends and experiences',
      estimatedDuration: Duration(minutes: 20),
      relevantSkills: ['industry_knowledge', 'market_analysis', 'trends'],
      idealFor: ['market_insights', 'industry_trends', 'competitive_analysis'],
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.mentorship,
      title: 'Professional Mentorship',
      description: 'Career guidance and professional development',
      estimatedDuration: Duration(minutes: 45),
      relevantSkills: ['mentoring', 'career_development', 'leadership'],
      idealFor: ['career_advice', 'skill_development', 'leadership_growth'],
      requiresPremium: true,
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.networking,
      title: 'Professional Networking',
      description: 'Build professional relationships and connections',
      estimatedDuration: Duration(minutes: 25),
      relevantSkills: ['networking', 'relationship_building', 'communication'],
      idealFor: ['professional_connections', 'industry_networking', 'relationship_building'],
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.projectPartnership,
      title: 'Project Partnership Exploration',
      description: 'Explore potential collaboration on projects',
      estimatedDuration: Duration(minutes: 40),
      relevantSkills: ['project_management', 'collaboration', 'partnership'],
      idealFor: ['project_collaboration', 'business_partnerships', 'joint_ventures'],
      requiresPremium: true,
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.jobOpportunity,
      title: 'Job Opportunity Discussion',
      description: 'Discuss potential employment or hiring opportunities',
      estimatedDuration: Duration(minutes: 30),
      relevantSkills: ['hiring', 'recruiting', 'talent_acquisition'],
      idealFor: ['job_opportunities', 'hiring_discussions', 'career_opportunities'],
      requiresPremium: true,
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.investmentDiscussion,
      title: 'Investment Discussion',
      description: 'Discuss funding, investment, or business opportunities',
      estimatedDuration: Duration(minutes: 45),
      relevantSkills: ['investment', 'funding', 'business_development'],
      idealFor: ['funding_opportunities', 'investment_discussions', 'business_growth'],
      requiresPremium: true,
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.knowledgeSharing,
      title: 'Knowledge Sharing Session',
      description: 'Share expertise and learn from each other',
      estimatedDuration: Duration(minutes: 35),
      relevantSkills: ['knowledge_sharing', 'teaching', 'learning'],
      idealFor: ['skill_exchange', 'knowledge_transfer', 'mutual_learning'],
    ),
    ProfessionalIntent(
      type: ProfessionalIntentType.eventConnection,
      title: 'Event Connection',
      description: 'Connect at a specific event or conference',
      estimatedDuration: Duration(minutes: 20),
      relevantSkills: ['event_networking', 'conference_connections'],
      idealFor: ['conference_networking', 'event_connections', 'meetup_connections'],
    ),
  ];

  static List<ProfessionalIntent> getIntentsForUserTier(bool isPremium) {
    if (isPremium) {
      return availableIntents;
    } else {
      return availableIntents.where((intent) => !intent.requiresPremium).toList();
    }
  }

  static ProfessionalIntent? getIntentByType(ProfessionalIntentType type) {
    try {
      return availableIntents.firstWhere((intent) => intent.type == type);
    } catch (e) {
      return null;
    }
  }

  String get durationDisplay {
    if (estimatedDuration.inMinutes < 60) {
      return '${estimatedDuration.inMinutes}min';
    } else {
      final hours = estimatedDuration.inHours;
      final minutes = estimatedDuration.inMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}min';
      }
    }
  }

  String get skillTags {
    return relevantSkills.take(3).join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'description': description,
      'estimatedDuration': estimatedDuration.inMinutes,
      'relevantSkills': relevantSkills,
      'idealFor': idealFor,
      'requiresPremium': requiresPremium,
    };
  }

  factory ProfessionalIntent.fromMap(Map<String, dynamic> map) {
    return ProfessionalIntent(
      type: ProfessionalIntentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ProfessionalIntentType.networking,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      estimatedDuration: Duration(minutes: map['estimatedDuration'] ?? 30),
      relevantSkills: List<String>.from(map['relevantSkills'] ?? []),
      idealFor: List<String>.from(map['idealFor'] ?? []),
      requiresPremium: map['requiresPremium'] ?? false,
    );
  }
}

class IntentSelection {
  final ProfessionalIntent intent;
  final String? customMessage;
  final DateTime selectedAt;
  final String? context;

  const IntentSelection({
    required this.intent,
    this.customMessage,
    required this.selectedAt,
    this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'intent': intent.toMap(),
      'customMessage': customMessage,
      'selectedAt': selectedAt.toIso8601String(),
      'context': context,
    };
  }

  factory IntentSelection.fromMap(Map<String, dynamic> map) {
    return IntentSelection(
      intent: ProfessionalIntent.fromMap(map['intent'] ?? {}),
      customMessage: map['customMessage'],
      selectedAt: DateTime.parse(map['selectedAt'] ?? DateTime.now().toIso8601String()),
      context: map['context'],
    );
  }
}
