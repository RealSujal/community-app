// 📄 Refactored: create_community_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  bool isLoading = false;
  String message = '';

  Future<void> handleCreate() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final location = locationController.text.trim();

    if (name.isEmpty || description.isEmpty || location.isEmpty) {
      setState(() => message = 'All fields are required.');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('$baseUrl/api/communities/create');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'location': location,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() => message = '✅ Community created!');
        Navigator.pop(context); // or go to dashboard
      } else {
        setState(() => message = data['message'] ?? 'Failed to create');
      }
    } catch (e) {
      setState(() => message = 'Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white60),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Create Community'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            buildTextField("Community Name", nameController),
            buildTextField("Location", locationController),
            buildTextField("Description", descriptionController),
            const SizedBox(height: 20),
            if (message.isNotEmpty)
              Text(message, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : handleCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("Create Community"),
            ),
          ],
        ),
      ),
    );
  }
}
