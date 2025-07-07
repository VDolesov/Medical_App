import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/norms_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/norms_screen.dart';
import 'screens/admin_reports_screen.dart';

void main() {
  runApp(const MedicalApp());
}

class MedicalApp extends StatelessWidget {
  const MedicalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => NormsProvider()),
      ],
      child: MedicalAppContent(),
    );
  }
}

class MedicalAppContent extends StatelessWidget {
   MedicalAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Медицинское приложение',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/upload',
            builder: (context, state) => const UploadScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
          GoRoute(
            path: '/norms',
            builder: (context, state) => const NormsScreen(),
          ),
          GoRoute(
            path: '/admin_reports',
            builder: (context, state) => const AdminReportsScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();
      final isLoggedIn = authProvider.isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        return '/home';
      }

      return null;
    },
  );
}

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(context),
        onTap: (index) => _onTabTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: 'Загрузка',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Отчеты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/home':
        return 0;
      case '/upload':
        return 1;
      case '/reports':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0;
    }
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/upload');
        break;
      case 2:
        context.go('/reports');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
} 