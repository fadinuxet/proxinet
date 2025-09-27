import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:putrace/putrace/putrace_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:putrace/core/services/putrace_secure_store.dart';
import 'package:putrace/core/services/putrace_crypto_service.dart';
import 'package:putrace/core/services/putrace_oauth_service.dart';
import 'package:putrace/core/services/putrace_contacts_service.dart';
import 'package:putrace/core/services/putrace_calendar_service.dart';
import 'package:putrace/core/services/putrace_presence_service.dart';
import 'package:putrace/core/services/putrace_local_store.dart';
import 'package:putrace/core/services/putrace_settings_service.dart';
import 'package:putrace/core/services/putrace_ble_service.dart';
import 'package:putrace/core/services/putrace_match_api.dart';
import 'package:putrace/core/services/serendipity_service.dart';
import 'package:putrace/core/services/notification_service.dart';
import 'package:putrace/core/services/firebase_repositories.dart';
import 'package:putrace/core/services/push_handler.dart';
import 'package:putrace/core/services/putrace_presence_sync_service.dart';
import 'package:putrace/features/messaging/domain/services/chat_service.dart';
import 'package:putrace/features/messaging/data/repositories/chat_repository.dart';
import 'package:putrace/core/services/connection_service.dart';
import 'package:putrace/core/services/smart_tagging_service.dart';
import 'package:putrace/core/services/simple_firebase_monitor.dart';
import 'package:putrace/features/putrace/data/services/venue_persistence_service.dart';
import 'package:putrace/core/services/interest_matching_service.dart';
import 'package:putrace/core/services/professional_auth_service.dart';
import 'package:putrace/core/services/secure_messaging_service.dart';
import 'package:putrace/core/services/ble_conference_mode_service.dart';
import 'core/services/user_tier_service.dart';
import 'core/services/anonymous_user_service.dart';
import 'core/services/anonymous_ble_service.dart';
import 'core/services/anonymous_privacy_service.dart';
import 'core/services/panic_mode_service.dart';
import 'core/services/dual_transport_service.dart';
import 'core/services/ble_state_service.dart';
import 'core/services/connection_request_service.dart';
import 'core/services/user_blocking_service.dart';
import 'core/services/professional_serendipity_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _setupDependencies();
  await _postInit();
  
  // Initialize Firebase monitoring
  await SimpleFirebaseMonitor.initialize();
  
  // Initialize new services
  await GetIt.instance<UserBlockingService>().initialize();
  await GetIt.instance<ProfessionalSerendipityEngine>();
  
  runApp(const PutraceApp());
}

Future<void> _setupDependencies() async {
  final sl = GetIt.instance;

  sl.registerLazySingleton<PutraceSecureStore>(() => PutraceSecureStore());
  sl.registerLazySingleton<PutraceCryptoService>(
      () => PutraceCryptoService(sl<PutraceSecureStore>()));
  sl.registerLazySingleton<PutraceOauthService>(() => PutraceOauthService());
  sl.registerLazySingleton<PutraceLocalStore>(() => PutraceLocalStore());
  sl.registerLazySingleton<PutraceContactsService>(() =>
      PutraceContactsService(
          sl<PutraceOauthService>(), sl<PutraceCryptoService>()));
  sl.registerLazySingleton<PutraceCalendarService>(
      () => PutraceCalendarService(sl<PutraceOauthService>()));
  sl.registerLazySingleton<PutracePresenceService>(
      () => PutracePresenceService());
  sl.registerLazySingleton<PutraceSettingsService>(
      () => PutraceSettingsService());
  sl.registerLazySingleton<PutracePresenceSyncService>(
      () => PutracePresenceSyncService());
  sl.registerLazySingleton<PutraceBleService>(() => PutraceBleService());
  sl.registerLazySingleton<PutraceMatchApi>(
      () => PutraceMatchApiStub(sl<PutraceLocalStore>()));
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
  
  // Privacy-First Services (Enterprise-Grade Security)
  sl.registerLazySingleton<ProfessionalAuthService>(() => 
      ProfessionalAuthService(sl<PutraceCryptoService>(), sl<PutraceSecureStore>()));
  sl.registerLazySingleton<SecureMessagingService>(() => 
      SecureMessagingService(sl<PutraceCryptoService>(), sl<ProfessionalAuthService>()));
  sl.registerLazySingleton<BLEConferenceModeService>(() => 
      BLEConferenceModeService(sl<PutraceCryptoService>(), sl<ProfessionalAuthService>()));
  
  // Venue Persistence Service
  sl.registerLazySingleton<VenuePersistenceService>(() => VenuePersistenceService());
  
  // User Tier Service
  sl.registerLazySingleton<UserTierService>(() => UserTierService());
  
  // Anonymous User Services
  sl.registerLazySingleton<AnonymousUserService>(() => AnonymousUserService());
  sl.registerLazySingleton<AnonymousBLEService>(() => AnonymousBLEService());
  sl.registerLazySingleton<AnonymousPrivacyService>(() => AnonymousPrivacyService());
  
  // Bitchat-Inspired Services
  sl.registerLazySingleton<PanicModeService>(() => PanicModeService());
  sl.registerLazySingleton<DualTransportService>(() => DualTransportService());
  
  // BLE State Management
  sl.registerLazySingleton<BLEStateService>(() => BLEStateService());
  
  // Connection Request Management
  sl.registerLazySingleton<ConnectionRequestService>(() => ConnectionRequestService());
  
  // Professional Serendipity & Blocking Services
  sl.registerLazySingleton<UserBlockingService>(() => UserBlockingService());
  sl.registerLazySingleton<ProfessionalSerendipityEngine>(() => ProfessionalSerendipityEngine());
}

Future<void> _postInit() async {
  // Enable offline persistence to reduce reads
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  // Request notification permission (Android 13+/iOS)
  await FirebaseMessaging.instance.requestPermission();
  // Authentication will be handled by AuthWrapper
  
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

class PutraceApp extends StatelessWidget {
  const PutraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Updated brand palette: vibrant yet professional
    final seed = const Color(0xFF6D28D9); // Deep violet
    final lightScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final darkScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp.router(
      title: 'Putrace',
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
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                try {
                  // Check if we can pop (go back) in the current route
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                    return; // Don't close the app
                  } else {
                    // If we can't pop (we're at the root), show exit dialog
                    final shouldExit = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Exit Putrace'),
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
                    
                    if (shouldExit) {
                      // Exit the app
                      SystemNavigator.pop();
                    }
                  }
                } catch (e) {
                  // Don't close the app on error
                  return;
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
      routerConfig: PutraceRouter.router,
    );
  }
}
