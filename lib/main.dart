import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:proxinet/proxinet/proxinet_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:proxinet/core/services/proxinet_secure_store.dart';
import 'package:proxinet/core/services/proxinet_crypto_service.dart';
import 'package:proxinet/core/services/proxinet_oauth_service.dart';
import 'package:proxinet/core/services/proxinet_contacts_service.dart';
import 'package:proxinet/core/services/proxinet_calendar_service.dart';
import 'package:proxinet/core/services/proxinet_presence_service.dart';
import 'package:proxinet/core/services/proxinet_local_store.dart';
import 'package:proxinet/core/services/proxinet_settings_service.dart';
import 'package:proxinet/core/services/proxinet_ble_service.dart';
import 'package:proxinet/core/services/proxinet_match_api.dart';
import 'package:proxinet/core/services/serendipity_service.dart';
import 'package:proxinet/core/services/notification_service.dart';
import 'package:proxinet/core/services/firebase_repositories.dart';
import 'package:proxinet/core/services/push_handler.dart';
import 'package:proxinet/core/services/proxinet_presence_sync_service.dart';
import 'package:proxinet/features/messaging/domain/services/chat_service.dart';
import 'package:proxinet/features/messaging/data/repositories/chat_repository.dart';
import 'package:proxinet/core/services/connection_service.dart';
import 'package:proxinet/core/services/smart_tagging_service.dart';
import 'package:proxinet/core/services/interest_matching_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _setupDependencies();
  await _postInit();
  runApp(const ProxinetApp());
}

Future<void> _setupDependencies() async {
  final sl = GetIt.instance;

  sl.registerLazySingleton<ProxinetSecureStore>(() => ProxinetSecureStore());
  sl.registerLazySingleton<ProxinetCryptoService>(
      () => ProxinetCryptoService(sl<ProxinetSecureStore>()));
  sl.registerLazySingleton<ProxinetOauthService>(() => ProxinetOauthService());
  sl.registerLazySingleton<ProxinetLocalStore>(() => ProxinetLocalStore());
  sl.registerLazySingleton<ProxinetContactsService>(() =>
      ProxinetContactsService(
          sl<ProxinetOauthService>(), sl<ProxinetCryptoService>()));
  sl.registerLazySingleton<ProxinetCalendarService>(
      () => ProxinetCalendarService(sl<ProxinetOauthService>()));
  sl.registerLazySingleton<ProxinetPresenceService>(
      () => ProxinetPresenceService());
  sl.registerLazySingleton<ProxinetSettingsService>(
      () => ProxinetSettingsService());
  sl.registerLazySingleton<ProxinetPresenceSyncService>(
      () => ProxinetPresenceSyncService());
  sl.registerLazySingleton<ProxinetBleService>(() => ProxinetBleService());
  sl.registerLazySingleton<ProxinetMatchApi>(
      () => ProxinetMatchApiStub(sl<ProxinetLocalStore>()));
  sl.registerLazySingleton<SerendipityService>(() => SerendipityService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<FirebasePostsRepo>(() => FirebasePostsRepo());
  sl.registerLazySingleton<FirebaseAvailabilityRepo>(
      () => FirebaseAvailabilityRepo());
  sl.registerLazySingleton<FirebaseReferralsRepo>(
      () => FirebaseReferralsRepo());
  sl.registerLazySingleton<FirebasePresenceRepo>(() => FirebasePresenceRepo());
  sl.registerLazySingleton<FirebaseDeviceRepo>(() => FirebaseDeviceRepo());

  // Messaging services
  sl.registerLazySingleton<ChatRepository>(() => ChatRepository());
  sl.registerLazySingleton<ChatService>(() => ChatService());

  // Connection services
  sl.registerLazySingleton<ConnectionService>(() => ConnectionService());

  // Serendipity services
  sl.registerLazySingleton<SmartTaggingService>(() => SmartTaggingService());
  sl.registerLazySingleton<InterestMatchingService>(() => InterestMatchingService());
}

Future<void> _postInit() async {
  // Enable offline persistence to reduce reads
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  // Request notification permission (Android 13+/iOS)
  await FirebaseMessaging.instance.requestPermission();
  // Authentication will be handled by AuthWrapper
  print('Firebase initialized successfully');
  // Background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await setupPushHandlers();
  // Upsert device token
  try {
    await GetIt.instance<FirebaseDeviceRepo>().upsertDeviceToken();
  } catch (_) {
    // Non-fatal: proceed even if token write fails (e.g., rules not yet deployed)
  }
}

class ProxinetApp extends StatelessWidget {
  const ProxinetApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Updated brand palette: vibrant yet professional
    final seed = const Color(0xFF6D28D9); // Deep violet
    final lightScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final darkScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp.router(
      title: 'ProxiNet',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Ensure proper display on devices with system navigation bars
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              // Ensure full screen display
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: WillPopScope(
              onWillPop: () async {
                try {
                  // Check if we can pop (go back) in the current route
                  if (Navigator.of(context).canPop()) {
                    print('Back button: can pop, going back');
                    Navigator.of(context).pop();
                    return false; // Don't close the app
                  } else {
                    // If we can't pop (we're at the root), show exit dialog
                    print('Back button: at root, showing exit dialog');
                    return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Exit ProxiNet'),
                            content: const Text(
                                'Are you sure you want to exit the app?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  }
                } catch (e) {
                  print('Error in WillPopScope: $e');
                  return false; // Don't close the app on error
                }
              },
              child: child!,
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        textTheme: GoogleFonts.interTextTheme(),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        }),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: lightScheme.onSurface),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: lightScheme.secondaryContainer,
          backgroundColor: lightScheme.surface,
          labelTextStyle: WidgetStateProperty.all(
              GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
        chipTheme: ChipThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: lightScheme.outlineVariant),
        ),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        textTheme: GoogleFonts.interTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        }),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: darkScheme.onSurface),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: darkScheme.secondaryContainer,
          backgroundColor: darkScheme.surface,
          labelTextStyle: WidgetStateProperty.all(
              GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
        chipTheme: ChipThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: darkScheme.outlineVariant),
        ),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      routerConfig: ProxinetRouter.router,
    );
  }
}
