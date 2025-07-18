import 'package:community_frontend/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:community_frontend/screens/notification_screen.dart';
import 'package:community_frontend/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  // final List<String> _titles = const [
  //   'Home',
  //   'Notifications',
  //   'Profile',
  // ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, //  prevents back button or swipe gesture
      child: Scaffold(
        backgroundColor: Colors.black,
        // appBar: AppBar(
        //   title: Text(_titles[_currentIndex]),
        //   backgroundColor: Colors.black,
        //   foregroundColor: Colors.white,
        //   centerTitle: true,
        //   automaticallyImplyLeading: false, // hides back arrow
        // ),
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none),
              activeIcon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
