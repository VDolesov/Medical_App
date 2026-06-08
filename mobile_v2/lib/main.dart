import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/expert_provider.dart';
import 'providers/reports_provider.dart';
import 'screens/admin/admin_knowledge_screen.dart';
import 'screens/admin/admin_patients_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chats_list_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reports/report_bind_screen.dart';
import 'screens/reports/report_detail_screen.dart';
import 'screens/reports/reports_list_screen.dart';
import 'screens/reports/upload_screen.dart';
import 'screens/shell/main_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  runApp(const MedicalAppV2());
}

class MedicalAppV2 extends StatefulWidget {
  const MedicalAppV2({super.key});

  @override
  State<MedicalAppV2> createState() => _MedicalAppV2State();
}

class _MedicalAppV2State extends State<MedicalAppV2> {
  late final ApiClient _api = ApiClient();
  late final AuthProvider _auth = AuthProvider(_api);
  late final ReportsProvider _reports = ReportsProvider(_api);
  late final ExpertProvider _expert = ExpertProvider(_api);
  late final ChatProvider _chat = ChatProvider(_api);
  late final GoRouter _router = _buildRouter();

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/home',
      refreshListenable: _auth,
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        ShellRoute(
          builder: (_, __, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
            GoRoute(
              path: '/reports',
              builder: (_, __) => const ReportsListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => ReportDetailScreen(
                    reportId: int.parse(state.pathParameters['id']!),
                  ),
                ),
                GoRoute(
                  path: ':id/bind',
                  builder: (_, state) => ReportBindScreen(
                    reportId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/chats',
              builder: (_, __) => const ChatsListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => ChatScreen(
                    threadId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminScreen(),
              routes: [
                GoRoute(path: 'knowledge', builder: (_, __) => const AdminKnowledgeScreen()),
                GoRoute(path: 'users', builder: (_, __) => const AdminUsersScreen()),
                GoRoute(path: 'patients', builder: (_, __) => const AdminPatientsScreen()),
                GoRoute(path: 'reports', builder: (_, __) => const AdminReportsScreen()),
              ],
            ),
          ],
        ),
      ],
      redirect: (context, state) {
        final loggedIn = _auth.isLoggedIn;
        final atLogin = state.matchedLocation == '/login' || state.matchedLocation == '/register';
        if (!loggedIn && !atLogin) return '/login';
        if (loggedIn && atLogin) return '/home';
        if (loggedIn && _auth.isPatient) {
          final loc = state.matchedLocation;
          if (loc == '/upload' || loc.startsWith('/admin')) return '/home';
        }
        if (loggedIn && !_auth.isAdmin && state.matchedLocation.startsWith('/admin')) {
          return '/home';
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
        ChangeNotifierProvider<ExpertProvider>.value(value: _expert),
        ChangeNotifierProvider<ChatProvider>.value(value: _chat),
      ],
      child: MaterialApp.router(
        title: 'Медицинская аналитика',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('en')],
        locale: const Locale('ru'),
        routerConfig: _router,
      ),
    );
  }
}
