import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/norms_provider.dart';
import 'providers/expert_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/admin_knowledge_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/norms_screen.dart';
import 'screens/admin_reports_screen.dart';
import 'screens/report_row_binding_screen.dart';
import 'screens/admin_patients_screen.dart';
import 'screens/doctor_patients_catalog_screen.dart';
import 'screens/chat_threads_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/admin_knowledge_screen.dart';
import 'screens/admin_rule_editor_screen.dart';

void main() {
  runApp(const MedicalApp());
}

class MedicalApp extends StatefulWidget {
  const MedicalApp({super.key});

  @override
  State<MedicalApp> createState() => _MedicalAppState();
}

class _MedicalAppState extends State<MedicalApp> {
  late final AuthProvider _auth = AuthProvider();
  late final ReportsProvider _reports = ReportsProvider();
  late final NormsProvider _norms = NormsProvider();
  late final ExpertProvider _expert = ExpertProvider();
  late final ChatProvider _chat = ChatProvider();
  late final AdminKnowledgeProvider _adminKnowledge = AdminKnowledgeProvider();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: _auth,
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
            GoRoute(
              path: '/reports/:rid/row-bind',
              builder: (context, state) {
                final rid = int.parse(state.pathParameters['rid']!);
                final isAdmin = state.extra == true;
                return ReportRowBindingScreen(reportId: rid, isAdmin: isAdmin);
              },
            ),
            GoRoute(
              path: '/admin/patients',
              builder: (context, state) => const AdminPatientsScreen(),
            ),
            GoRoute(
              path: '/doctor/patients',
              builder: (context, state) => const DoctorPatientsCatalogScreen(),
            ),
            GoRoute(
              path: '/chats',
              builder: (context, state) => const ChatThreadsScreen(),
            ),
            GoRoute(
              path: '/chat/:tid',
              builder: (context, state) {
                final tid = int.parse(state.pathParameters['tid']!);
                return ChatScreen(threadId: tid);
              },
            ),
            GoRoute(
              path: '/admin/knowledge',
              builder: (context, state) => const AdminKnowledgeScreen(),
            ),
            GoRoute(
              path: '/admin/knowledge/new',
              builder: (context, state) => const AdminRuleEditorScreen(),
            ),
            GoRoute(
              path: '/admin/knowledge/:id',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return AdminRuleEditorScreen(id: id);
              },
            ),
          ],
        ),
      ],
      redirect: (context, state) {
        final isLoggedIn = _auth.isLoggedIn;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!isLoggedIn && !isLoginRoute) {
          return '/login';
        }

        if (isLoggedIn && isLoginRoute) {
          return '/home';
        }

        if (isLoggedIn && _auth.isPatient) {
          final loc = state.matchedLocation;
          if (loc == '/upload' || loc == '/admin' || loc == '/admin_reports' || loc == '/admin/patients') {
            return '/home';
          }
          if (loc.startsWith('/admin/knowledge')) {
            return '/home';
          }
          if (loc.contains('/row-bind')) {
            return '/home';
          }
          if (loc.startsWith('/doctor')) {
            return '/home';
          }
        }

        if (isLoggedIn && !_auth.isAdmin) {
          final loc = state.matchedLocation;
          if (loc == '/admin' ||
              loc == '/admin_reports' ||
              loc == '/admin/patients' ||
              loc.startsWith('/admin/knowledge')) {
            return '/home';
          }
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<ReportsProvider>.value(value: _reports),
        ChangeNotifierProvider<NormsProvider>.value(value: _norms),
        ChangeNotifierProvider<ExpertProvider>.value(value: _expert),
        ChangeNotifierProvider<ChatProvider>.value(value: _chat),
        ChangeNotifierProvider<AdminKnowledgeProvider>.value(value: _adminKnowledge),
      ],
      child: MaterialApp.router(
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
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _unreadFetched = false;

  @override
  Widget build(BuildContext context) {
    if (!_unreadFetched) {
      _unreadFetched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        if (auth.isLoggedIn) {
          context.read<ChatProvider>().refreshUnreadCount(auth);
        }
      });
    }
    return _MainLayoutBody(child: widget.child);
  }
}

class _MainLayoutBody extends StatelessWidget {
  final Widget child;

  const _MainLayoutBody({required this.child});

  static List<BottomNavigationBarItem> _staffItems(int unread) => [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
        const BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: 'Загрузка'),
        const BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Отчеты'),
        BottomNavigationBarItem(icon: _chatIcon(unread), label: 'Чаты'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ];

  static List<BottomNavigationBarItem> _patientItems(int unread) => [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
        const BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Отчеты'),
        BottomNavigationBarItem(icon: _chatIcon(unread), label: 'Чаты'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ];

  static Widget _chatIcon(int unread) {
    if (unread <= 0) return const Icon(Icons.chat_bubble_outline);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, auth, chat, _) {
        final isPatient = auth.isPatient;
        final unread = chat.unreadTotal;
        return Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: isPatient ? _patientIndex(context) : _staffIndex(context),
            onTap: (index) => isPatient ? _onPatientTab(context, index) : _onStaffTab(context, index),
            items: isPatient ? _patientItems(unread) : _staffItems(unread),
          ),
        );
      },
    );
  }

  int _staffIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/home':
        return 0;
      case '/upload':
        return 1;
      case '/reports':
        return 2;
      case '/chats':
        return 3;
      case '/profile':
        return 4;
      default:
        if (location.startsWith('/chat')) return 3;
        return 0;
    }
  }

  int _patientIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/home':
        return 0;
      case '/reports':
        return 1;
      case '/chats':
        return 2;
      case '/profile':
        return 3;
      default:
        if (location.startsWith('/chat')) return 2;
        return 0;
    }
  }

  void _onStaffTab(BuildContext context, int index) {
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
        context.go('/chats');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  void _onPatientTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/reports');
        break;
      case 2:
        context.go('/chats');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}
