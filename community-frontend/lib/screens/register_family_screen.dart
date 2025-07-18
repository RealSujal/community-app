import 'dart:convert';
import 'package:community_frontend/screens/add_member_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart'; // contains baseUrl

class RegisterFamilyScreen extends StatefulWidget {
  const RegisterFamilyScreen({super.key});

  @override
  State<RegisterFamilyScreen> createState() => _RegisterFamilyScreenState();
}

class _RegisterFamilyScreenState extends State<RegisterFamilyScreen> {
  final familyNameController = TextEditingController();
  final addressController = TextEditingController();

  bool isLoading = false;
  String message = '';
  bool isError = false;

  Future<void> _registerFamily() async {
    final familyName = familyNameController.text.trim();
    final address = addressController.text.trim();

    if (familyName.isEmpty) {
      setState(() {
        message = 'Family Name is required';
        isError = true;
      });
      return;
    }

    if (address.isEmpty) {
      setState(() {
        message = 'Address is required';
        isError = true;
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/register-family'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'family_name': familyName,
          'address': address,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final familyId = data['familyId'];

        if (familyId != null) {
          print("Received familyId: $familyId");

          await prefs.setInt('family_id', familyId);

          final savedId = prefs.getInt('family_id');
          print("Saved family_id to prefs: $savedId");

          if (savedId == familyId) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AddMemberScreen(),
              ),
            );
          } else {
            setState(() {
              message = 'Failed to store family ID.';
              isError = true;
            });
          }
        } else {
          print("familyId is null in response");
          setState(() {
            message = 'Failed to retrieve family ID.';
            isError = true;
          });
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          message = data['message'] ?? 'Registration failed';
          isError = true;
        });
      }
    } catch (e) {
      setState(() {
        message = 'Error: $e';
        isError = true;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    familyNameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register Family'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField("Family Name *", familyNameController),
            _buildTextField("Address *", addressController),
            const SizedBox(height: 16),
            if (message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isError
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isError ? Colors.red : Colors.green,
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError ? Colors.red : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _registerFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}
