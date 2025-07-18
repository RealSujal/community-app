// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'feed_screen.dart';
import 'event_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final tabs = ['Feed', 'Events'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'dashboard':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
    }
  }

  TextStyle _tabTextStyle(bool isSelected) => TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.grey,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Home'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuSelection(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'dashboard',
                child: Text('Dashboard'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          tabs: List.generate(tabs.length, (index) {
            final isSelected = _tabController.index == index;
            return Tab(
                child: Text(tabs[index], style: _tabTextStyle(isSelected)));
          }),
          onTap: (_) => setState(() {}), // Updates tab label styles
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FeedScreen(),
          EventScreen(),
        ],
      ),
    );
  }
}
