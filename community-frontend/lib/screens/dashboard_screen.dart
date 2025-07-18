import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = true;
  bool isError = false;
  String message = '';
  Map<String, dynamic> community = {};
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          isLoading = false;
          isError = true;
          message = "User not logged in.";
        });
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final communityRes = await http.get(
        Uri.parse('$baseUrl/api/communities/my-community'),
        headers: headers,
      );

      final statsRes = await http.get(
        Uri.parse('$baseUrl/api/communities/dashboard'),
        headers: headers,
      );

      if (communityRes.statusCode == 200 && statsRes.statusCode == 200) {
        setState(() {
          community = jsonDecode(communityRes.body)['community'];
          stats = jsonDecode(statsRes.body)['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          message = 'Failed to load dashboard';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isError = true;
        message = 'Error: $e';
      });
    }
  }

  Widget buildStatCard(String label, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 32),
          const SizedBox(height: 10),
          Text(
            "$value",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : isError
              ? Center(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community['name'] ?? 'Unknown Community',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${community['location']} • Role: ${community['role']}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Invite Code: ${community['invite_code']}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/members'),
                            child: buildStatCard(
                                "Members", stats['members'], Icons.group),
                          ),
                          buildStatCard(
                              "Posts", stats['posts'], Icons.post_add),
                          buildStatCard(
                              "Comments", stats['comments'], Icons.comment),
                          buildStatCard(
                              "Likes", stats['likes'], Icons.favorite),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
