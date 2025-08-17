import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/widgets/auth_wrapper.dart';
import '../features/proxinet/presentation/pages/proxinet_onboarding_page.dart';
import '../features/proxinet/presentation/pages/proxinet_home_page.dart';
import '../features/proxinet/presentation/pages/connect_accounts_page.dart';
import '../features/proxinet/presentation/pages/privacy_controls_page.dart';
import '../features/proxinet/presentation/pages/camera_view_page.dart';
import '../features/proxinet/presentation/pages/proxinet_map_page.dart';
import '../features/proxinet/presentation/pages/serendipity_post_composer_page.dart';
import '../features/proxinet/presentation/pages/serendipity_posts_page.dart';
import '../features/proxinet/presentation/pages/availability_page.dart';
import '../features/proxinet/presentation/pages/nearby_page.dart';
import '../features/proxinet/presentation/pages/referrals_page.dart';
import '../features/proxinet/presentation/pages/groups_page.dart';
import '../features/proxinet/presentation/pages/profile_page.dart';
import '../features/proxinet/presentation/pages/contacts_page.dart';
import '../features/proxinet/presentation/pages/notifications_page.dart';
import '../features/proxinet/presentation/pages/user_guide_page.dart';
import '../features/proxinet/presentation/pages/simple_guide_page.dart';

class ProxinetRouter {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  static const String onboarding = '/proxinet/onboarding';
  static const String home = '/proxinet';
  static const String connect = '/proxinet/connect';
  static const String privacy = '/proxinet/privacy';
  static const String camera = '/proxinet/camera';
  static const String map = '/proxinet/map';
  static const String post = '/proxinet/post';
  static const String posts = '/proxinet/posts';
  static const String availability = '/proxinet/availability';
  static const String nearby = '/proxinet/nearby';
  static const String referrals = '/proxinet/referrals';
  static const String groups = '/proxinet/groups';
  static const String profile = '/proxinet/profile';
  static const String contacts = '/proxinet/contacts';
  static const String notifications = '/notifications';
  static const String userGuide = '/guide';
  static const String simpleGuide = '/simple-guide';

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
        builder: (context, state) => const ProxinetOnboardingPage(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const ProxinetHomePage(),
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
        builder: (context, state) => const ProxinetMapPage(),
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
        path: referrals,
        builder: (context, state) => const ReferralsPage(),
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
