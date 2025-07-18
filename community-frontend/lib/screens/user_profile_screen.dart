import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? user;
  bool isCurrentUser = false;
  bool isLoading = true;

  Map<String, dynamic> privacy = {};
  List<dynamic> familyRelations = [];
  bool isRelationsLoading = false;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '-';
    try {
      final date = DateTime.parse(rawDate).toLocal();
      return "${_monthName(date.month)} ${date.day}, ${date.year}";
    } catch (_) {
      return rawDate; // fallback to raw value if parsing fails
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  static const platform = MethodChannel('com.yourapp/email');

  Future<void> launchGmailCompose(String email) async {
    try {
      final success =
          await platform.invokeMethod('openGmail', {'email': email});
      if (success != true) {
        throw 'Gmail not available';
      }
    } on PlatformException catch (e) {
      debugPrint('Error opening Gmail: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't open Gmail: ${e.message}")),
      );
    }
  }

  Future<void> fetchFamilyRelations(int personId) async {
    setState(() {
      isRelationsLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final res = await http.get(
        Uri.parse('$baseUrl/api/profile/$personId/family-relations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          familyRelations = data['relations'] ?? [];
          isRelationsLoading = false;
        });
      } else {
        setState(() {
          isRelationsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isRelationsLoading = false;
      });
    }
  }

  Future<void> loadUserProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? loggedInUserId = prefs.getInt('userId');

    final token = prefs.getString('token');
    final apiUrl = '$baseUrl/api/users/${widget.userId}';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("User Data: ${jsonEncode(data['user'])}");

        setState(() {
          user = data['user'];
          privacy = data['privacy'] ?? {};
          isCurrentUser = loggedInUserId == user!['id'];
          isLoading = false;
        });

        // Try to get family relations if person_id exists
        if (user != null && user!['person_id'] != null) {
          fetchFamilyRelations(user!['person_id']);
        } else if (user != null && user!['name'] != null) {
          // If no person_id, try to find the person by name to get family relations
          await _findPersonAndFetchRelations(user!['name']);
        }

        debugPrint("Privacy Settings: $privacy");
      } else {
        throw Exception("Failed to load profile");
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  Future<void> _findPersonAndFetchRelations(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      // Search for person by name
      final res = await http.get(
        Uri.parse('$baseUrl/api/people?name=${Uri.encodeComponent(name)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final people = data['people'] ?? [];

        if (people.isNotEmpty) {
          // Use the first person found with this name
          final person = people.first;
          fetchFamilyRelations(person['id']);
        }
      }
    } catch (e) {
      debugPrint('Find person error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          (user!['role'] ?? 'Member').toString().toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildFamilySection(),
            if (isCurrentUser) ...[
              const SizedBox(height: 24),
              _buildFamilyButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[800],
          backgroundImage: user!['profile_picture'] != null
              ? NetworkImage(user!['profile_picture'])
              : null,
          child: user!['profile_picture'] == null
              ? Text(
                  user!['name'][0].toUpperCase(),
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user!['phone'] != null && (privacy['phone'] ?? true))
              IconButton(
                icon: const Icon(Icons.call, color: Colors.white),
                onPressed: () async {
                  final phone = Uri.encodeComponent(user!['phone']);
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    debugPrint('Could not launch $uri');
                  }
                },
              ),
            if (user!['email'] != null && (privacy['email'] ?? true))
              IconButton(
                icon: const Icon(Icons.mail_outline, color: Colors.white),
                onPressed: () async {
                  final email = Uri.encodeComponent(user!['email']);
                  launchGmailCompose(email);
                },
              ),
            if (isCurrentUser)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.pushNamed(context, '/edit-profile');
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _infoRow(Icons.person, 'Name', user!['name']),
          if (privacy['email'] != null)
            _infoRow(Icons.email, 'E-mail', user!['email']),
          if (privacy['phone'] ?? true)
            _infoRow(Icons.phone, 'Phone number', user!['phone']),
          if (privacy['dob'] ?? true)
            _infoRow(Icons.cake, 'Date of Birth', _formatDate(user!['dob'])),
          if (privacy['gender'] ?? true)
            _infoRow(Icons.wc, 'Gender', user!['gender']),
          if (privacy['location'] ?? true)
            _infoRow(Icons.home, 'Home address', user!['location']),
        ],
      ),
    );
  }

  Widget _buildFamilySection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Family",
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          isRelationsLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : familyRelations.isEmpty
                  ? const Text("No family members found.",
                      style: TextStyle(color: Colors.white70))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: familyRelations.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12),
                      itemBuilder: (context, idx) {
                        final rel = familyRelations[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.person, color: Colors.white),
                          title: GestureDetector(
                            onTap: () {
                              if (rel['id'] != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                        userId: rel['user_id']),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              rel['name'] ?? '',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            rel['relation'] ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value ?? '-',
                    style: const TextStyle(fontSize: 16, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/manage-family');
        },
        icon: const Icon(Icons.family_restroom),
        label: const Text("Manage Family"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
