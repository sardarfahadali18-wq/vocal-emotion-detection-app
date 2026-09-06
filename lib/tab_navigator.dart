import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recorder_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart' as login; // For AppColors

class TabNavigator extends StatefulWidget {
  final int initialIndex;

  const TabNavigator({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<TabNavigator>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Server URL state - use IP that works for physical devices
  String _serverUrl =
      'http://192.168.1.100:5000'; // Default that should be changed by user

  // Define the pages
  late List<Widget> _pages;

  final List<String> _titles = [
    'Vocal Emotion Analyzer',
    'History',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Initialize pages with default URL first
    _initPages();

    // Then load the URL from SharedPreferences and update if needed
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString('server_url');
      if (storedUrl != null && storedUrl.isNotEmpty) {
        if (storedUrl != _serverUrl) {
          setState(() {
            _serverUrl = storedUrl;
            _initPages();
          });
        }
      }
    } catch (e) {
      print('Error loading server URL: $e');
    }
  }

  void _refreshPages() {
    setState(() {
      _initPages();
    });
  }

  void _initPages() {
    print('Creating pages with server URL: $_serverUrl');
    _pages = [
      // Use a key based on the URL to force recreation when URL changes
      HomeScreen(
        key: ValueKey('home_$_serverUrl'),
        serverUrl: _serverUrl,
      ),
      HistoryScreen(
        key: ValueKey('history_$_serverUrl'),
        serverUrl: _serverUrl,
      ),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // Give haptic feedback
            HapticFeedback.lightImpact();

            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: login.AppColors.primary,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
