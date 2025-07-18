// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/constants.dart';
import 'add_member_screen.dart';
import 'register_family_screen.dart';

class ManageFamilyScreen extends StatefulWidget {
  const ManageFamilyScreen({super.key});

  @override
  State<ManageFamilyScreen> createState() => _ManageFamilyScreenState();
}

class _ManageFamilyScreenState extends State<ManageFamilyScreen> {
  bool isLoading = true;
  Map<String, dynamic>? family;
  List<dynamic> members = [];

  @override
  void initState() {
    super.initState();
    _fetchFamilyData();
  }

  Future<void> _fetchFamilyData() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      debugPrint("No token found");
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-family'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Family response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['familyExists'] == false) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RegisterFamilyScreen()),
          );
          return;
        }

        final fetchedMembers = data['members'] ?? [];

        // Remove the duplicate email check - let the backend handle this during creation
        // The family data should be displayed regardless of duplicate emails

        setState(() {
          family = data['family'];
          members = fetchedMembers;
        });
      } else {
        debugPrint("Failed to fetch family data (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Exception: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildMemberCard(Map<String, dynamic> member, bool isHead) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/person-detail',
            arguments: member,
          );
        },
        title: Text(
          member['name'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          isHead ? "Head of Family" : (member['relation'] ?? 'Member'),
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white38, size: 18),
            if (!isHead) ...[
              const SizedBox(width: 8),
              IconButton(
                icon:
                    const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                tooltip: 'Remove Member',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove Member'),
                      content: Text(
                          'Are you sure you want to remove ${member['name']} from the family?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('token');
                    if (token == null) return;
                    final response = await http.delete(
                      Uri.parse('$baseUrl/api/person/${member['id']}'),
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                    );
                    if (response.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Member removed'),
                            backgroundColor: Colors.green),
                      );
                      _fetchFamilyData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to remove member'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Manage Family"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Family: ${family?['family_name'] ?? '—'}",
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  if (family?['head_name'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Head: ${family?['head_name']}",
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                  if (family?['contact_number'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Contact: ${family?['contact_number']}",
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    "Members:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: members.isEmpty
                        ? const Center(
                            child: Text(
                              "No members yet",
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : (() {
                            // Find the head (lowest ID)
                            final headId = members
                                .map((m) => m['id'])
                                .reduce((a, b) => a < b ? a : b);
                            final head =
                                members.firstWhere((m) => m['id'] == headId);
                            // Filter out the head from the non-head members list
                            final nonHeadMembers = members
                                .where((m) => m['id'] != headId)
                                .toList();
                            return ListView(
                              children: [
                                _buildMemberCard(head, true),
                                ...nonHeadMembers.map((member) =>
                                    _buildMemberCard(member, false)),
                              ],
                            );
                          })(),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMemberScreen(
                              existingCount: members.length,
                            ),
                          ),
                        ).then((_) => _fetchFamilyData());
                      },
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text("Add Member"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
