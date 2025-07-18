import 'package:community_frontend/helpers/storage_helper.dart';
import 'package:community_frontend/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

    final token = await getToken();
    final uri = Uri.parse(
        '$baseUrl/api/community/members?name=$searchName&location=$selectedLocation');

    final res = await http.get(uri, headers: authHeader(token));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List<dynamic> fetchedMembers = data['members'];

      final userId = await getUserId();
      if (userId == null) {
        setState(() {
          isLoading = false;
          currentRole = '';
          members = [];
        });
        return;
      }
      final myRole = getMyRole(fetchedMembers, userId);
      final sorted = sortMembers(fetchedMembers);
      final locations = getUniqueLocations(fetchedMembers);

      setState(() {
        currentRole = myRole;
        members = sorted;
        allLocations = locations;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  String getMyRole(List<dynamic> memberList, int userId) {
    final me = memberList.firstWhere(
      (m) => m['id'] == userId,
      orElse: () => null,
    );
    return me?['role'] ?? '';
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
    final token = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/api/users/promote/$userId'),
      headers: authHeader(token),
    );
    if (res.statusCode == 200) {
      fetchMembers();
    }
  }

  Future<void> removeMember(int userId) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/community/remove-member/$userId'),
      headers: authHeader(token),
    );
    if (res.statusCode == 200) {
      fetchMembers();
    }
  }

  void showActionSheet(dynamic member) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (member['role'] == 'member')
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: const Text('Promote to Admin'),
                  onTap: () {
                    Navigator.pop(context);
                    promoteMember(member['id']);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Member'),
                onTap: () {
                  Navigator.pop(context);
                  removeMember(member['id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildMemberCard(dynamic member) {
    final isHead = member['role'] == 'head';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: member['id']),
          ),
        );
      },
      onLongPress: () {
        if (['admin', 'head'].contains(currentRole) &&
            member['role'] != 'head') {
          showActionSheet(member);
        }
      },
      child: Card(
        color: isHead ? Colors.amber[100] : Theme.of(context).cardColor,
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: member['profile_picture'] != null
                ? NetworkImage(member['profile_picture'])
                : null,
            child: member['profile_picture'] == null
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(
            member['name'],
            style: TextStyle(
              fontWeight: isHead ? FontWeight.bold : FontWeight.normal,
              color: isHead ? Colors.black : null,
            ),
          ),
          subtitle: Text(member['role'].toUpperCase()),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }

  Widget buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name',
                prefixIcon: Icon(Icons.search),
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
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                backgroundColor: Colors.black,
                builder: (BuildContext context) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.grey[900],
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.grey,
                            labelText: 'Select Location',
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                          value: selectedLocation.isEmpty
                              ? null
                              : selectedLocation,
                          items: allLocations.map((loc) {
                            return DropdownMenuItem(
                              value: loc,
                              child: Text(loc,
                                  style: const TextStyle(color: Colors.white)),
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
            icon: const Icon(Icons.filter_list, color: Colors.black),
            label: const Text(
              'Filter',
              style: TextStyle(color: Colors.black),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(
                  color: Color(0xFFB197FC)), // light purple border
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        title: const Text('Members'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                buildFilters(),
                Expanded(
                  child: members.isEmpty
                      ? const Center(child: Text("No members found."))
                      : ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (ctx, i) => buildMemberCard(members[i]),
                        ),
                ),
              ],
            ),
    );
  }
}
