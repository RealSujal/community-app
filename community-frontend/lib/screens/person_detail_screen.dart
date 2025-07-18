import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/constants.dart';

class PersonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> person;

  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late Map<String, dynamic> person;
  List<Map<String, dynamic>> reverseRelations = [];
  String? relationToHead;

  @override
  void initState() {
    super.initState();
    person = widget.person;
    _checkIfPersonIsHead();
  }

  void _checkIfPersonIsHead() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getInt('userId');

    if (person['added_by_user_id'] == currentUserId) {
      _fetchReverseRelations();
    }
  }

  Future<void> _refreshPerson() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final res = await http.get(
      Uri.parse('$baseUrl/api/person/${person['id']}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final relationRes = await http.get(
      Uri.parse('$baseUrl/api/relations/${person['id']}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        person = data['person'];
      });
    }

    if (relationRes.statusCode == 200) {
      final data = jsonDecode(relationRes.body);
      final List relations = data['relations'] ?? [];

      if (relations.isNotEmpty) {
        final rel = relations.first;
        final relationType = rel['relation_type'];
        final relatedName = rel['relation_person_name'];

        setState(() {
          if (relationType != null && relatedName != null) {
            relationToHead = "$relationType of $relatedName";
          } else {
            relationToHead = null;
          }
        });
      } else {
        setState(() {
          relationToHead = null;
        });
      }
    }
  }

  Future<void> _fetchReverseRelations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final res = await http.get(
      Uri.parse('$baseUrl/api/relations/${person['id']}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        reverseRelations = List<Map<String, dynamic>>.from(data['relations']);
      });
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "—";
    try {
      final parsedDate = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: Text(person['name'] ?? 'Person Details'),
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.pushNamed(
                context,
                '/edit-person',
                arguments: person,
              );
              if (updated == true) await _refreshPerson();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(),
            const SizedBox(height: 24),
            if ((person['relation'] == null ||
                    person['relation'].toString().isEmpty) &&
                reverseRelations.isNotEmpty)
              _relationCard()
            else if (person['relation'] != null)
              detailTile("Relation", person['relation']),
            if (relationToHead != null &&
                relationToHead!.contains("null") == false)
              detailTile("Relation to Head", relationToHead),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detailTile("Name", person['name']),
          detailTile("Phone", person['phone']),
          detailTile("Email", person['email']),
          detailTile("Address", person['address']),
          const SizedBox(height: 12),
          detailTile("Gender", person['gender']),
          detailTile("Date of Birth", _formatDate(person['dob'])),
          detailTile("Age", person['age']?.toString()),
        ],
      ),
    );
  }

  Widget _relationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Relations",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...reverseRelations.map((rel) {
            print('Relation Data: $rel');
            final relation =
                (rel['self_relation']?.toString().isNotEmpty == true)
                    ? rel['self_relation']
                    : rel['relation_type'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rel['related_person_name'] ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    relation ?? '',
                    style: const TextStyle(color: Colors.white70),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget detailTile(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          Expanded(
            child: Text(
              value ?? "—",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
