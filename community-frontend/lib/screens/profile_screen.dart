import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  Map<String, dynamic> user = {};

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          user = jsonDecode(res.body)['user'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _confirmAction(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(
              title == 'Delete Account'
                  ? Icons.delete
                  : title == 'Leave Community'
                      ? Icons.warning
                      : Icons.logout,
              color: title == 'Delete Account' ? Colors.red : Colors.amber,
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  title == 'Delete Account' ? Colors.red : Colors.amber,
            ),
            child: const Text("Confirm"),
          )
        ],
      ),
    );
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _leaveCommunity() {
    // TODO: Implement API call
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Left community successfully")),
    );
  }

  void _deleteAccount() {
    // TODO: Implement API call
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account deleted")),
    );
  }

  Widget buildTile(IconData icon, String label, VoidCallback onTap,
      {Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing:
          const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = user['name'] ?? 'Loading...';
    final String email = user['email'] ?? '';
    final String imageUrl = user['profile_picture'] != null &&
            user['profile_picture'].isNotEmpty
        ? user['profile_picture']
        : 'https://ui-avatars.com/api/?name=$name&background=0D8ABC&color=fff';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Profile"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(imageUrl),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(email,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  buildTile(Icons.edit, "Edit Profile", () async {
                    await Navigator.pushNamed(context, '/edit-profile');
                    fetchUserProfile();
                  }),
                  buildTile(Icons.lock_outline, "Privacy & Security", () {
                    Navigator.pushNamed(context, '/privacy');
                  }),
                  buildTile(Icons.groups, "Manage Family", () {
                    Navigator.pushNamed(context, '/manage-family');
                  }),
                  buildTile(Icons.help_outline, "Help & Feedback", () {
                    Navigator.pushNamed(context, '/help-feedback');
                  }),
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white12),
                  buildTile(
                    Icons.logout,
                    "Logout",
                    () => _confirmAction(
                        "Logout", "Are you sure you want to logout?", _logout),
                    iconColor: Colors.red,
                  ),
                  buildTile(
                    Icons.exit_to_app,
                    "Leave Community",
                    () => _confirmAction(
                        "Leave Community",
                        "Are you sure you want to leave the community?",
                        _leaveCommunity),
                    iconColor: Colors.red,
                  ),
                  buildTile(
                    Icons.delete_forever,
                    "Delete Account",
                    () => _confirmAction(
                        "Delete Account",
                        "This action is irreversible. Proceed?",
                        _deleteAccount),
                    iconColor: Colors.red,
                  ),
                ],
              ),
            ),
    );
  }
}
