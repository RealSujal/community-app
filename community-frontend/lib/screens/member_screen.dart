// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:community_frontend/helpers/storage_helper.dart';
import 'package:community_frontend/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../constants/constants.dart';

class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  List<dynamic> members = [];
  String currentRole = '';
  int? currentUserId;
  bool isLoading = true;
  String searchName = '';
  String selectedLocation = '';
  List<String> allLocations = [];

  TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    setState(() => isLoading = true);

    try {
      final token = await getToken();

      if (token == null) {
        setState(() => isLoading = false);
        return;
      }

      final uri = Uri.parse(
        '$baseUrl/api/communities/members' +
            (searchName.isNotEmpty ? '?name=$searchName' : '') +
            (selectedLocation.isNotEmpty
                ? (searchName.isNotEmpty ? '&' : '?') +
                    'location=$selectedLocation'
                : ''),
      );

      final res = await http.get(uri, headers: authHeader(token));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> fetchedMembers = data['members'];

        final userId = await getUserId();

        // Temporary fix: If userId is null, try to get it from the members list
        int? finalUserId = userId;
        if (finalUserId == null && fetchedMembers.isNotEmpty) {
          // Try to find the current user by looking for the head
          final headMember = fetchedMembers.firstWhere(
            (m) => m['role'] == 'head',
            orElse: () => null,
          );
          if (headMember != null) {
            finalUserId = headMember['id'];
          }
        }

        final myRole =
            finalUserId != null ? getMyRole(fetchedMembers, finalUserId) : '';
        final sorted = sortMembers(fetchedMembers);
        final locations = getUniqueLocations(fetchedMembers);

        setState(() {
          currentRole = myRole;
          currentUserId = finalUserId;
          members = sorted;
          allLocations = locations;
          isLoading = false;
        });
      } else {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to fetch members')),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching members: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  String getMyRole(List<dynamic> memberList, int userId) {
    try {
      final me = memberList.firstWhere(
        (m) => m['id'].toString() == userId.toString(),
        orElse: () => null,
      );
      return me?['role'] ?? '';
    } catch (e) {
      return '';
    }
  }

  List<String> getUniqueLocations(List<dynamic> memberList) {
    final unique = memberList
        .map<String>((m) => m['location']?.toString() ?? '')
        .where((loc) => loc.isNotEmpty)
        .toSet()
        .toList();
    unique.sort();
    return unique;
  }

  List<dynamic> sortMembers(List<dynamic> list) {
    final head = list.where((m) => m['role'] == 'head').toList();
    final rest = list.where((m) => m['role'] != 'head').toList();
    return [...head, ...rest];
  }

  Future<void> promoteMember(int userId) async {
    try {
      setState(() => isLoading = true);
      final token = await getToken();
      final res = await http.put(
        Uri.parse('$baseUrl/api/users/promote/$userId'),
        headers: authHeader(token),
      );

      if (res.statusCode == 200) {
        await fetchMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member promoted successfully!')),
        );
      } else {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Failed to promote member')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error promoting member: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> demoteMember(int userId) async {
    try {
      setState(() => isLoading = true);
      final token = await getToken();
      final res = await http.put(
        Uri.parse('$baseUrl/api/users/demote/$userId'),
        headers: authHeader(token),
      );

      if (res.statusCode == 200) {
        await fetchMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Admin demoted to member successfully!')),
        );
      } else {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to demote admin')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error demoting admin: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> removeMember(int userId) async {
    try {
      setState(() => isLoading = true);
      final token = await getToken();
      final res = await http.delete(
        Uri.parse('$baseUrl/api/communities/remove-member/$userId'),
        headers: authHeader(token),
      );

      if (res.statusCode == 200) {
        await fetchMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed successfully!')),
        );
      } else {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to remove member')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing member: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget buildMemberCard(dynamic member) {
    final isHead = member['role'] == 'head';
    final isAdmin = member['role'] == 'admin';
    final isCurrentUserHead = currentRole == 'head';
    final isCurrentUserAdmin = currentRole == 'admin';
    final isCurrentUser = currentUserId == member['id'];

    // Head can manage everyone except themselves
    // Admin can manage members and other admins, but not heads
    final canManage = (isCurrentUserHead || isCurrentUserAdmin) &&
        (isCurrentUserHead ? true : member['role'] != 'head') &&
        !isCurrentUser; // Prevent self-management

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: member['id']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isHead ? Colors.amber.withOpacity(0.1) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: isHead
              ? Border.all(color: Colors.amber, width: 2)
              : Border.all(color: Colors.grey[700]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Picture
              CircleAvatar(
                radius: 25,
                backgroundImage: member['profile_picture'] != null
                    ? NetworkImage(member['profile_picture'])
                    : null,
                backgroundColor: Colors.grey[700],
                child: member['profile_picture'] == null
                    ? Icon(Icons.person, size: 30, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(width: 16),

              // Name and Location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isHead ? FontWeight.bold : FontWeight.w600,
                        color: isHead ? Colors.amber : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member['location'] ?? 'No location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Role Tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHead
                      ? Colors.amber.withOpacity(0.2)
                      : isAdmin
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHead
                        ? Colors.amber
                        : isAdmin
                            ? Colors.blue
                            : Colors.grey[600]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  member['role'].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isHead
                        ? Colors.amber
                        : isAdmin
                            ? Colors.blue
                            : Colors.grey[300],
                  ),
                ),
              ),

              // Three dot menu (only for admin/head)
              if (canManage) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'promote':
                        promoteMember(member['id']);
                        break;
                      case 'demote':
                        demoteMember(member['id']);
                        break;
                      case 'remove':
                        removeMember(member['id']);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    if (member['role'] == 'member')
                      PopupMenuItem<String>(
                        value: 'promote',
                        child: Row(
                          children: const [
                            Icon(Icons.arrow_upward,
                                color: Colors.white, size: 18),
                            SizedBox(width: 12),
                            Text(
                              'Promote to Admin',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    if (member['role'] == 'admin')
                      PopupMenuItem<String>(
                        value: 'demote',
                        child: Row(
                          children: const [
                            Icon(Icons.arrow_downward,
                                color: Colors.orange, size: 18),
                            SizedBox(width: 12),
                            Text(
                              'Demote to Member',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        children: const [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 12),
                          Text(
                            'Remove Member',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    setState(() => searchName = val);
                    fetchMembers();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  backgroundColor: Colors.grey[900],
                  builder: (BuildContext context) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            dropdownColor: Colors.grey[900],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[800],
                              labelText: 'Select Location',
                              labelStyle: const TextStyle(color: Colors.white),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                            ),
                            value: selectedLocation.isEmpty
                                ? null
                                : selectedLocation,
                            items: allLocations.map((loc) {
                              return DropdownMenuItem(
                                value: loc,
                                child: Text(loc,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => selectedLocation = val ?? '');
                            },
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              fetchMembers();
                            },
                            child: const Text('Apply Filter'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: const Icon(Icons.filter_list, color: Colors.grey, size: 20),
              label: const Text(
                'Filter',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Members',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                buildFilters(),
                Expanded(
                  child: members.isEmpty
                      ? const Center(
                          child: Text(
                            "No members found.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: members.length,
                          itemBuilder: (ctx, i) => buildMemberCard(members[i]),
                        ),
                ),
              ],
            ),
    );
  }
}
