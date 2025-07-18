import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/constants.dart';

class EditPersonScreen extends StatefulWidget {
  final Map<String, dynamic> person;

  const EditPersonScreen({super.key, required this.person});

  @override
  State<EditPersonScreen> createState() => _EditPersonScreenState();
}

class _EditPersonScreenState extends State<EditPersonScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController genderController;
  late TextEditingController dobController;
  late TextEditingController ageController;
  late TextEditingController relationController;
  late TextEditingController addressController;
  late TextEditingController phoneController;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    nameController = TextEditingController(text: p['name']);
    emailController = TextEditingController(text: p['email'] ?? '');
    genderController = TextEditingController(text: p['gender'] ?? '');

    DateTime? parsedDob;
    try {
      parsedDob = DateTime.parse(p['dob']);
    } catch (_) {}

    dobController = TextEditingController(
      text: parsedDob != null ? DateFormat('yyyy-MM-dd').format(parsedDob) : '',
    );

    if (parsedDob != null) {
      final now = DateTime.now();
      int age = now.year - parsedDob.year;
      if (now.month < parsedDob.month ||
          (now.month == parsedDob.month && now.day < parsedDob.day)) {
        age--;
      }
      ageController = TextEditingController(text: age.toString());
    } else {
      ageController = TextEditingController(text: p['age']?.toString() ?? '');
    }

    relationController = TextEditingController(text: p['relation']);
    addressController = TextEditingController(text: p['address']);
    phoneController = TextEditingController(text: p['phone']);
  }

  Future<void> _updatePerson() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token missing. Please login again')),
      );
      return;
    }

    final res = await http.put(
      Uri.parse('$baseUrl/api/person/${widget.person['id']}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'gender': genderController.text.trim(),
        'dob': dobController.text.trim(),
        'age': ageController.text.trim(),
        'relation': relationController.text.trim(),
        'address': addressController.text.trim(),
        'phone': phoneController.text.trim(),
      }),
    );

    if (res.statusCode == 200) {
      Navigator.pop(context, true);
    } else {
      try {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Update failed')),
        );
      } catch (err) {
        debugPrint("Unexpected response: ${res.body}");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected error occurred')));
      }
    }

    setState(() => isLoading = false);
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    final List<String> genderOptions = ['Male', 'Female', 'Other'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: genderOptions.contains(genderController.text)
            ? genderController.text
            : null,
        items: genderOptions
            .map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                ))
            .toList(),
        onChanged: (value) {
          genderController.text = value ?? '';
        },
        decoration: InputDecoration(
          labelText: "Gender",
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: Colors.grey[900],
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(dobController.text) ?? DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );

        if (picked != null) {
          final formatted = DateFormat('yyyy-MM-dd').format(picked);
          dobController.text = formatted;

          final now = DateTime.now();
          int age = now.year - picked.year;
          if (now.month < picked.month ||
              (now.month == picked.month && now.day < picked.day)) {
            age--;
          }
          ageController.text = age.toString();
        }
      },
      child: AbsorbPointer(
        child: _buildTextField("Date of Birth", dobController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Person"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField("Name", nameController),
            _buildTextField("Email", emailController,
                type: TextInputType.emailAddress),
            _buildGenderDropdown(),
            _buildDatePickerField(),
            _buildTextField("Age", ageController, type: TextInputType.number),
            _buildTextField("Relation", relationController),
            _buildTextField("Address", addressController),
            _buildTextField("Phone", phoneController,
                type: TextInputType.phone),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _updatePerson,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
