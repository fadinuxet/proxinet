import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/login_page.dart';
import '../pages/signup_page.dart';
import '../../../proxinet/presentation/pages/proxinet_home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return const ProxinetHomePage();
        }
        
        // User is not signed in, show auth pages
        return const AuthNavigator();
      },
    );
  }
}

class AuthNavigator extends StatelessWidget {
  const AuthNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: '/auth/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/auth/login':
            return MaterialPageRoute(
              builder: (context) => const LoginPage(),
            );
          case '/auth/signup':
            return MaterialPageRoute(
              builder: (context) => const SignupPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const LoginPage(),
            );
        }
      },
    );
  }
}
