import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  Map<String, bool> privacySettings = {
    'phone': true,
    'email': true,
    'dob': true,
    'address': true,
    'social_links': true,
  };

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPrivacySettings();
  }

  Future<void> _fetchPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    final res = await http.get(
      Uri.parse('$baseUrl/api/privacy'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        for (var key in privacySettings.keys) {
          privacySettings[key] = (data[key] == 1 || data[key] == true);
        }
        isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String field, bool value) async {
    setState(() {
      privacySettings[field] = value;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    await http.put(
      Uri.parse('$baseUrl/api/privacy'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({field: value}),
    );
  }

  Widget buildToggle(String label, String field) {
    return SwitchListTile(
      value: privacySettings[field] ?? true,
      onChanged: (val) => _updateSetting(field, val),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      activeColor: Colors.greenAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Visibility Settings',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 10),
                buildToggle('Show Phone', 'phone'),
                buildToggle('Show Email', 'email'),
                buildToggle('Show Date of Birth', 'dob'),
                buildToggle('Show Address', 'address'),
                buildToggle('Show Social Links', 'social_links'),
                const SizedBox(height: 30),
                const Divider(color: Colors.white24),
                ListTile(
                  title: const Text(
                    'Change Password',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 18),
                  onTap: () => Navigator.pushNamed(context, '/change-password'),
                ),
              ],
            ),
    );
  }
}
