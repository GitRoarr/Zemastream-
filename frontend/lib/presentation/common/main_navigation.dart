import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_routes.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart' as libScreen;
import '../profile/profile_screen.dart';
import '../profile/listener_profile.dart';
import '../profile/artist_profile.dart';
import '../profile/admin_profile.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late int _currentIndex;
  final GlobalKey<State<HomeScreen>> _homeScreenKey = GlobalKey<State<HomeScreen>>();
  final GlobalKey<State<libScreen.LibraryScreen>> _libraryScreenKey = GlobalKey<State<libScreen.LibraryScreen>>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3); // Ensure index is within bounds
  }

  Widget _buildProfileScreen() {
    final userState = ref.watch(userProvider);
    final user = userState.user;

    if (user == null) {
      return const Center(child: Text('User not logged in', style: TextStyle(color: Colors.white)));
    }

    switch (user.role.toLowerCase()) {
      case 'listener':
        return const ListenerProfile();
      case 'artist':
        return const ArtistProfile();
      case 'admin':
        return const AdminProfile();
      default:
        return const ProfileScreen();
    }
  }

  List<Widget> _buildTabs() {
    return [
      HomeScreen(key: _homeScreenKey),
      const SearchScreen(),
      libScreen.LibraryScreen(key: _libraryScreenKey),
      _buildProfileScreen(), // Dynamic profile screen based on user role
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _buildTabs(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) async {
          if (i == 3) { // Profile tab
            setState(() {
              _currentIndex = i; // Update to show profile screen
            });
          } else {
            setState(() {
              _currentIndex = i;
            });

            if (i == 0) {
              final homeState = _homeScreenKey.currentState as libScreen.RefreshableScreen?;
              await homeState?.refreshData();
            }
            if (i == 2) {
              final libraryState = _libraryScreenKey.currentState as libScreen.RefreshableScreen?;
              await libraryState?.refreshData();
            }
          }
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).unselectedWidgetColor,
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}