import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/widgets/auth_wrapper.dart';
import '../features/putrace/presentation/pages/putrace_onboarding_page.dart';
import '../features/putrace/presentation/pages/putrace_home_page.dart';
import '../features/putrace/presentation/pages/connect_accounts_page.dart';
import '../features/putrace/presentation/pages/privacy_controls_page.dart';
import '../features/putrace/presentation/pages/camera_view_page.dart';
import '../features/putrace/presentation/pages/putrace_map_page.dart';
import '../features/putrace/presentation/pages/serendipity_post_composer_page.dart';
import '../features/putrace/presentation/pages/serendipity_posts_page.dart';
import '../features/putrace/presentation/pages/availability_page.dart';
import '../features/putrace/presentation/pages/nearby_page.dart';
import '../features/putrace/presentation/pages/groups_page.dart';
import '../features/putrace/presentation/pages/profile_page.dart';
import '../features/putrace/presentation/pages/contacts_page.dart';
import '../features/putrace/presentation/pages/notifications_page.dart';
import '../features/putrace/presentation/pages/user_guide_page.dart';
import '../features/putrace/presentation/pages/simple_guide_page.dart';
import '../features/putrace/presentation/pages/ble_diagnostic_page.dart';
import '../features/messaging/presentation/pages/messages_page.dart';
import '../features/putrace/presentation/pages/available_people_page.dart';
import '../features/putrace/presentation/pages/connections_page.dart';
import '../features/putrace/presentation/pages/content_discovery_page.dart';

class PutraceRouter {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  static const String onboarding = '/putrace/onboarding';
  static const String home = '/putrace';
  static const String connect = '/putrace/connect';
  static const String privacy = '/putrace/privacy';
  static const String camera = '/putrace/camera';
  static const String map = '/putrace/map';
  static const String post = '/putrace/post';
  static const String posts = '/putrace/posts';
  static const String availability = '/putrace/availability';
  static const String nearby = '/putrace/nearby';
  static const String referrals = '/putrace/referrals';
  static const String groups = '/putrace/groups';
  static const String profile = '/putrace/profile';
  static const String contacts = '/putrace/contacts';
  static const String notifications = '/notifications';
  static const String userGuide = '/guide';
  static const String simpleGuide = '/simple-guide';
  static const String bleDiagnostic = '/putrace/ble-diagnostic';
  static const String messages = '/putrace/messages';
  static const String availablePeople = '/putrace/available-people';
  static const String connections = '/putrace/connections';
  static const String contentDiscovery = '/putrace/discover';

  static final GoRouter router = GoRouter(
    navigatorKey: navKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthWrapper(),
      ),
      GoRoute(
        path: onboarding,
        builder: (context, state) => const PutraceOnboardingPage(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const PutraceHomePage(),
      ),
      GoRoute(
        path: connect,
        builder: (context, state) => const ConnectAccountsPage(),
      ),
      GoRoute(
        path: privacy,
        builder: (context, state) => const PrivacyControlsPage(),
      ),
      GoRoute(
        path: camera,
        builder: (context, state) => const CameraViewPage(),
      ),
      GoRoute(
        path: map,
        builder: (context, state) => const PutraceMapPage(),
      ),
      GoRoute(
        path: post,
        builder: (context, state) => const SerendipityPostComposerPage(),
      ),
      GoRoute(
        path: posts,
        builder: (context, state) => const SerendipityPostsPage(),
      ),
      GoRoute(
        path: availability,
        builder: (context, state) => const AvailabilityPage(),
      ),
      GoRoute(
        path: nearby,
        builder: (context, state) => const NearbyPage(),
      ),
      GoRoute(
        path: bleDiagnostic,
        builder: (context, state) => const BleDiagnosticPage(),
      ),
      GoRoute(
        path: messages,
        builder: (context, state) => const MessagesPage(),
      ),
      GoRoute(
        path: availablePeople,
        builder: (context, state) => const AvailablePeoplePage(),
      ),
      GoRoute(
        path: connections,
        builder: (context, state) => const ConnectionsPage(),
      ),
      GoRoute(
        path: contentDiscovery,
        builder: (context, state) => const ContentDiscoveryPage(),
      ),
      GoRoute(
        path: groups,
        builder: (context, state) => const GroupsPage(),
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: contacts,
        builder: (context, state) => const ContactsPage(),
      ),
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: userGuide,
        builder: (context, state) => const UserGuidePage(),
      ),
      GoRoute(
        path: simpleGuide,
        builder: (context, state) => const SimpleGuidePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
