import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'anonymous_user_service.dart';

class OpportunityScore {
  final double overall;
  final Map<String, double> breakdown;
  final List<String> insights;
  final List<String> suggestedActions;
  final String? primaryOpportunity;
  final String? urgencyLevel;

  const OpportunityScore({
    required this.overall,
    required this.breakdown,
    required this.insights,
    required this.suggestedActions,
    this.primaryOpportunity,
    this.urgencyLevel,
  });

  bool get isHighValue => overall > 0.7;
  bool get isMediumValue => overall > 0.4 && overall <= 0.7;
  bool get isLowValue => overall <= 0.4;

  String get displayScore => '${(overall * 100).toInt()}% match';
  
  Color get scoreColor {
    if (isHighValue) return const Color(0xFF4CAF50); // Green
    if (isMediumValue) return const Color(0xFFFF9800); // Orange
    return const Color(0xFF9E9E9E); // Grey
  }
}

class ProfessionalContext {
  final List<String> topSkills;
  final String? industry;
  final String? companySize;
  final String? careerStage;
  final List<String> interests;
  final String? location;
  final DateTime? lastActive;

  const ProfessionalContext({
    required this.topSkills,
    this.industry,
    this.companySize,
    this.careerStage,
    required this.interests,
    this.location,
    this.lastActive,
  });

  factory ProfessionalContext.fromUserProfile(UserProfile profile) {
    return ProfessionalContext(
      topSkills: profile.skills,
      industry: profile.industry,
      companySize: _estimateCompanySize(profile.company),
      careerStage: _estimateCareerStage(profile.title),
      interests: profile.interests,
      location: profile.location,
      lastActive: profile.updatedAt,
    );
  }

  factory ProfessionalContext.fromAnonymousProfile(AnonymousUserProfile profile) {
    return ProfessionalContext(
      topSkills: [profile.role],
      industry: _inferIndustryFromRole(profile.role),
      companySize: _estimateCompanySize(profile.company),
      careerStage: _estimateCareerStage(profile.role),
      interests: [profile.role, profile.company ?? ''],
      location: null,
      lastActive: DateTime.now(),
    );
  }

  static String? _estimateCompanySize(String? company) {
    if (company == null) return null;
    final companyLower = company.toLowerCase();
    if (companyLower.contains('startup') || companyLower.contains('incubator')) return 'startup';
    if (companyLower.contains('enterprise') || companyLower.contains('corp')) return 'enterprise';
    return 'mid-size';
  }

  static String? _estimateCareerStage(String? title) {
    if (title == null) return null;
    final titleLower = title.toLowerCase();
    if (titleLower.contains('senior') || titleLower.contains('lead') || titleLower.contains('principal')) return 'senior';
    if (titleLower.contains('junior') || titleLower.contains('entry')) return 'junior';
    if (titleLower.contains('director') || titleLower.contains('vp') || titleLower.contains('cto')) return 'executive';
    return 'mid-level';
  }

  static String? _inferIndustryFromRole(String role) {
    final roleLower = role.toLowerCase();
    if (roleLower.contains('software') || roleLower.contains('engineer') || roleLower.contains('developer')) return 'technology';
    if (roleLower.contains('design') || roleLower.contains('ux') || roleLower.contains('ui')) return 'design';
    if (roleLower.contains('product') || roleLower.contains('manager')) return 'product';
    if (roleLower.contains('marketing') || roleLower.contains('growth')) return 'marketing';
    if (roleLower.contains('sales') || roleLower.contains('business')) return 'business';
    return 'professional';
  }
}

class ProfessionalSerendipityEngine {
  static final ProfessionalSerendipityEngine _instance = ProfessionalSerendipityEngine._internal();
  factory ProfessionalSerendipityEngine() => _instance;
  ProfessionalSerendipityEngine._internal();

  final Random _random = Random();

  Future<OpportunityScore> calculateOpportunityScore(
    dynamic userA,
    dynamic userB, {
    String? context,
    DateTime? timeContext,
  }) async {
    try {
      final contextA = _extractContext(userA);
      final contextB = _extractContext(userB);

      final breakdown = <String, double>{};
      final insights = <String>[];
      final suggestedActions = <String>[];

      // Calculate skill complementarity (40% weight)
      final skillScore = await _calculateSkillComplementarity(contextA, contextB);
      breakdown['skills'] = skillScore;
      if (skillScore > 0.7) {
        insights.add('Strong skill complementarity detected');
        suggestedActions.add('Discuss technical collaboration opportunities');
      }

      // Calculate industry relevance (30% weight)
      final industryScore = await _calculateIndustryRelevance(contextA, contextB);
      breakdown['industry'] = industryScore;
      if (industryScore > 0.6) {
        insights.add('Same industry - potential for knowledge sharing');
        suggestedActions.add('Share industry insights and trends');
      }

      // Calculate timing opportunity (20% weight)
      final timingScore = await _calculateTimingOpportunity(contextA, contextB, timeContext);
      breakdown['timing'] = timingScore;
      if (timingScore > 0.8) {
        insights.add('Perfect timing for professional connection');
        suggestedActions.add('Act quickly - high-value opportunity');
      }

      // Calculate network value (10% weight)
      final networkScore = await _calculateNetworkValue(contextA, contextB);
      breakdown['network'] = networkScore;
      if (networkScore > 0.6) {
        insights.add('High network value potential');
        suggestedActions.add('Explore mutual connections and introductions');
      }

      // Calculate overall score
      final overall = (skillScore * 0.4) + (industryScore * 0.3) + (timingScore * 0.2) + (networkScore * 0.1);

      // Generate primary opportunity
      final primaryOpportunity = _generatePrimaryOpportunity(contextA, contextB, breakdown);

      // Determine urgency level
      final urgencyLevel = _determineUrgencyLevel(overall, timingScore);

      return OpportunityScore(
        overall: overall,
        breakdown: breakdown,
        insights: insights,
        suggestedActions: suggestedActions,
        primaryOpportunity: primaryOpportunity,
        urgencyLevel: urgencyLevel,
      );
    } catch (e) {
      debugPrint('Error calculating opportunity score: $e');
      return const OpportunityScore(
        overall: 0.0,
        breakdown: {},
        insights: [],
        suggestedActions: [],
      );
    }
  }

  ProfessionalContext _extractContext(dynamic user) {
    if (user is UserProfile) {
      return ProfessionalContext.fromUserProfile(user);
    } else if (user is AnonymousUserProfile) {
      return ProfessionalContext.fromAnonymousProfile(user);
    } else {
      // Fallback for other types
      return const ProfessionalContext(
        topSkills: [],
        interests: [],
      );
    }
  }

  Future<double> _calculateSkillComplementarity(ProfessionalContext contextA, ProfessionalContext contextB) async {
    if (contextA.topSkills.isEmpty || contextB.topSkills.isEmpty) return 0.0;

    final skillsA = contextA.topSkills.map((s) => s.toLowerCase()).toSet();
    final skillsB = contextB.topSkills.map((s) => s.toLowerCase()).toSet();

    // Calculate overlap
    final overlap = skillsA.intersection(skillsB).length;
    final total = skillsA.union(skillsB).length;

    if (total == 0) return 0.0;

    final overlapScore = overlap / total;

    // Boost for complementary skills
    final complementaryScore = _calculateComplementarySkills(skillsA, skillsB);

    return (overlapScore * 0.6) + (complementaryScore * 0.4);
  }

  double _calculateComplementarySkills(Set<String> skillsA, Set<String> skillsB) {
    // Define complementary skill pairs
    final complementaryPairs = {
      'frontend': 'backend',
      'design': 'development',
      'product': 'engineering',
      'marketing': 'sales',
      'data': 'engineering',
      'devops': 'development',
      'mobile': 'backend',
      'ai': 'data',
    };

    double score = 0.0;
    for (final skillA in skillsA) {
      for (final skillB in skillsB) {
        if (complementaryPairs[skillA] == skillB || complementaryPairs[skillB] == skillA) {
          score += 0.3;
        }
      }
    }

    return min(score, 1.0);
  }

  Future<double> _calculateIndustryRelevance(ProfessionalContext contextA, ProfessionalContext contextB) async {
    if (contextA.industry == null || contextB.industry == null) return 0.0;

    if (contextA.industry == contextB.industry) return 1.0;

    // Calculate related industries
    final relatedIndustries = _getRelatedIndustries(contextA.industry!);
    if (relatedIndustries.contains(contextB.industry)) return 0.7;

    return 0.0;
  }

  List<String> _getRelatedIndustries(String industry) {
    final relatedMap = {
      'technology': ['software', 'saas', 'fintech', 'edtech', 'healthtech'],
      'finance': ['fintech', 'banking', 'investment', 'cryptocurrency'],
      'healthcare': ['healthtech', 'biotech', 'pharmaceuticals'],
      'education': ['edtech', 'training', 'e-learning'],
      'retail': ['e-commerce', 'marketplace', 'logistics'],
    };

    return relatedMap[industry.toLowerCase()] ?? [];
  }

  Future<double> _calculateTimingOpportunity(ProfessionalContext contextA, ProfessionalContext contextB, DateTime? timeContext) async {
    // Base timing score
    double score = 0.5;

    // Boost for recent activity
    if (contextA.lastActive != null && contextA.lastActive!.isAfter(DateTime.now().subtract(const Duration(hours: 24)))) {
      score += 0.2;
    }
    if (contextB.lastActive != null && contextB.lastActive!.isAfter(DateTime.now().subtract(const Duration(hours: 24)))) {
      score += 0.2;
    }

    // Boost for business hours
    final now = timeContext ?? DateTime.now();
    if (now.hour >= 9 && now.hour <= 17) {
      score += 0.1;
    }

    return min(score, 1.0);
  }

  Future<double> _calculateNetworkValue(ProfessionalContext contextA, ProfessionalContext contextB) async {
    double score = 0.0;

    // Company size complementarity
    if (contextA.companySize != null && contextB.companySize != null) {
      if (contextA.companySize == 'startup' && contextB.companySize == 'enterprise') {
        score += 0.4; // Startup-enterprise connections are valuable
      } else if (contextA.companySize == 'enterprise' && contextB.companySize == 'startup') {
        score += 0.4;
      } else if (contextA.companySize == contextB.companySize) {
        score += 0.2; // Same company size
      }
    }

    // Career stage complementarity
    if (contextA.careerStage != null && contextB.careerStage != null) {
      if (contextA.careerStage == 'junior' && contextB.careerStage == 'senior') {
        score += 0.3; // Mentorship potential
      } else if (contextA.careerStage == 'senior' && contextB.careerStage == 'junior') {
        score += 0.3;
      } else if (contextA.careerStage == contextB.careerStage) {
        score += 0.2; // Peer connections
      }
    }

    // Location relevance
    if (contextA.location != null && contextB.location != null) {
      if (contextA.location == contextB.location) {
        score += 0.1; // Same location
      }
    }

    return min(score, 1.0);
  }

  String _generatePrimaryOpportunity(ProfessionalContext contextA, ProfessionalContext contextB, Map<String, double> breakdown) {
    if (breakdown['skills'] != null && breakdown['skills']! > 0.7) {
      return 'Technical collaboration opportunity';
    }
    if (breakdown['industry'] != null && breakdown['industry']! > 0.6) {
      return 'Industry knowledge sharing';
    }
    if (breakdown['network'] != null && breakdown['network']! > 0.6) {
      return 'Professional networking opportunity';
    }
    return 'Professional connection opportunity';
  }

  String _determineUrgencyLevel(double overallScore, double timingScore) {
    if (overallScore > 0.8 && timingScore > 0.7) return 'high';
    if (overallScore > 0.6 && timingScore > 0.5) return 'medium';
    return 'low';
  }

  Future<List<String>> generateAIIcebreakers(dynamic userA, dynamic userB, OpportunityScore score) async {
    final contextA = _extractContext(userA);
    final contextB = _extractContext(userB);
    final icebreakers = <String>[];

    // High-value opportunity icebreakers
    if (score.isHighValue) {
      icebreakers.addAll([
        'I see we both work on ${_getCommonSkills(contextA, contextB)} - would love to discuss challenges and solutions',
        'Your experience in ${contextB.industry ?? 'your field'} aligns perfectly with what I\'m working on',
        'I noticed we have complementary skills - could we explore collaboration opportunities?',
      ]);
    }

    // Industry-specific icebreakers
    if (contextA.industry == contextB.industry && contextA.industry != null) {
      icebreakers.addAll([
        'Fellow ${contextA.industry} professional! How are you navigating the current market trends?',
        'I\'d love to get your perspective on ${contextA.industry} challenges we\'re both facing',
      ]);
    }

    // Skill-based icebreakers
    final commonSkills = _getCommonSkills(contextA, contextB);
    if (commonSkills.isNotEmpty) {
      icebreakers.addAll([
        'I see we both work with $commonSkills - would you be open to a quick technical discussion?',
        'Your $commonSkills expertise could be valuable for a project I\'m working on',
      ]);
    }

    // Company size complementarity
    if (contextA.companySize == 'startup' && contextB.companySize == 'enterprise') {
      icebreakers.add('I\'d love to learn from your enterprise experience while sharing startup insights');
    } else if (contextA.companySize == 'enterprise' && contextB.companySize == 'startup') {
      icebreakers.add('Your startup perspective would be valuable for our enterprise challenges');
    }

    // Career stage icebreakers
    if (contextA.careerStage == 'junior' && contextB.careerStage == 'senior') {
      icebreakers.add('I\'d appreciate any advice you might have for someone in my career stage');
    } else if (contextA.careerStage == 'senior' && contextB.careerStage == 'junior') {
      icebreakers.add('I\'d be happy to share insights from my experience in the field');
    }

    // Fallback icebreakers
    if (icebreakers.isEmpty) {
      icebreakers.addAll([
        'Hi! I\'d love to connect and learn about your professional journey',
        'Would you be interested in a brief professional conversation?',
        'I noticed we\'re both in the professional networking space - care to connect?',
      ]);
    }

    return icebreakers.take(3).toList();
  }

  String _getCommonSkills(ProfessionalContext contextA, ProfessionalContext contextB) {
    final skillsA = contextA.topSkills.map((s) => s.toLowerCase()).toSet();
    final skillsB = contextB.topSkills.map((s) => s.toLowerCase()).toSet();
    final common = skillsA.intersection(skillsB);
    return common.isNotEmpty ? common.first : 'technology';
  }

  Future<List<String>> generateProfessionalIntents(dynamic userA, dynamic userB, OpportunityScore score) async {
    final intents = <String>[];

    if (score.isHighValue) {
      intents.addAll([
        'Technical collaboration discussion',
        'Industry insights exchange',
        'Professional mentorship',
        'Project partnership exploration',
      ]);
    } else if (score.isMediumValue) {
      intents.addAll([
        'Quick professional advice',
        'Industry trend discussion',
        'Networking opportunity',
        'Knowledge sharing',
      ]);
    } else {
      intents.addAll([
        'Professional introduction',
        'Brief networking chat',
        'Industry connection',
      ]);
    }

    return intents;
  }
}
