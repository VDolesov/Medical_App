import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _unreadFetched = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = _buildTabs(auth);
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _selectedIndex(location, tabs);

    if (!_unreadFetched) {
      _unreadFetched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (auth.isLoggedIn) {
          context.read<ChatProvider>().refreshUnread();
        }
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(tabs[i].route),
            destinations: tabs.map((t) => _destinationFor(t)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _destinationFor(_NavTab tab) {
    if (tab.label == 'Чаты') {
      return NavigationDestination(
        icon: Consumer<ChatProvider>(
          builder: (_, chat, __) => _ChatIcon(unread: chat.unreadTotal, selected: false),
        ),
        selectedIcon: Consumer<ChatProvider>(
          builder: (_, chat, __) => _ChatIcon(unread: chat.unreadTotal, selected: true),
        ),
        label: tab.label,
      );
    }
    return NavigationDestination(
      icon: Icon(tab.icon),
      selectedIcon: Icon(tab.selectedIcon),
      label: tab.label,
    );
  }

  int _selectedIndex(String loc, List<_NavTab> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      if (loc == tabs[i].route || loc.startsWith('${tabs[i].route}/')) return i;
    }
    return 0;
  }

  List<_NavTab> _buildTabs(AuthProvider auth) {
    if (auth.isPatient) {
      return const [
        _NavTab('/home', Icons.dashboard_outlined, Icons.dashboard, 'Главная'),
        _NavTab('/reports', Icons.description_outlined, Icons.description, 'Отчёты'),
        _NavTab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'Чаты'),
        _NavTab('/profile', Icons.person_outline, Icons.person, 'Профиль'),
      ];
    }
    if (auth.isAdmin) {
      return const [
        _NavTab('/home', Icons.dashboard_outlined, Icons.dashboard, 'Главная'),
        _NavTab('/reports', Icons.description_outlined, Icons.description, 'Отчёты'),
        _NavTab('/admin', Icons.shield_outlined, Icons.shield, 'Админка'),
        _NavTab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'Чаты'),
        _NavTab('/profile', Icons.person_outline, Icons.person, 'Профиль'),
      ];
    }

    return const [
      _NavTab('/home', Icons.dashboard_outlined, Icons.dashboard, 'Главная'),
      _NavTab('/upload', Icons.upload_file_outlined, Icons.upload_file, 'Загрузка'),
      _NavTab('/reports', Icons.description_outlined, Icons.description, 'Отчёты'),
      _NavTab('/chats', Icons.chat_bubble_outline, Icons.chat_bubble, 'Чаты'),
      _NavTab('/profile', Icons.person_outline, Icons.person, 'Профиль'),
    ];
  }
}

class _NavTab {
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavTab(this.route, this.icon, this.selectedIcon, this.label);
}

class _ChatIcon extends StatelessWidget {
  final int unread;
  final bool selected;
  const _ChatIcon({required this.unread, required this.selected});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline);
    if (unread <= 0) return icon;
    return Badge(
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: icon,
    );
  }
}
