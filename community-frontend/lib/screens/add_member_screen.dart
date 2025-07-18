import 'dart:convert';

import 'package:community_frontend/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddMemberScreen extends StatefulWidget {
  final int existingCount;
  const AddMemberScreen({Key? key, this.existingCount = 0}) : super(key: key);

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  List<Map<String, TextEditingController>> memberControllers = [];
  bool isLoading = false;
  int currentFamilyMemberCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCurrentFamilyMemberCount();
  }

  Future<void> _fetchCurrentFamilyMemberCount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final familyId = prefs.getInt('family_id');

    if (token == null || familyId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-family'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['family_exists'] == true) {
          final memberCount = (data['members'] ?? []).length;
          setState(() {
            currentFamilyMemberCount = memberCount;
          });
          if (memberCount == 0) {
            _addNewMember();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching family member count: $e');
    }

    // Start with head of family
    _addNewMember();
  }

  void _addNewMember() {
    setState(() {
      memberControllers.add({
        'name': TextEditingController(),
        'gender': TextEditingController(),
        'dob': TextEditingController(),
        'age': TextEditingController(),
        'relation': TextEditingController(),
        'address': TextEditingController(),
        'phone': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  Future<bool> _saveMember(int index) async {
    final member = memberControllers[index];
    // Only the first member in an empty family is head
    final isHead = currentFamilyMemberCount == 0 && index == 0;

    // Required fields
    final requiredFields = [
      'name',
      'gender',
      'dob',
      'age',
      'phone',
      if (!isHead) 'relation',
    ];
    for (final field in requiredFields) {
      if (member[field]!.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Please enter ${field[0].toUpperCase()}${field.substring(1)} for Member ${index + 1}'),
          backgroundColor: Colors.red,
        ));
        return false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final familyId = prefs.getInt('family_id');
    if (token == null || familyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Auth failed. Please log in again.'),
        backgroundColor: Colors.red,
      ));
      return false;
    }
    final memberData = {
      'name': member['name']!.text,
      'gender': member['gender']!.text,
      'dob': member['dob']!.text,
      'age': member['age']!.text,
      'address': member['address']!.text,
      'phone': member['phone']!.text,
      'email': member['email']!.text,
      'family_id': familyId,
      if (!isHead) 'relation': member['relation']!.text,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/person'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(memberData),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);

      // If it's a duplicate member (409), skip it gracefully
      if (response.statusCode == 409) {
        debugPrint('Skipping duplicate member: ${data['message']}');
        return true; // Treat as success to skip this member
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['message'] ?? 'Failed to add Member ${index + 1}'),
        backgroundColor: Colors.red,
      ));
      return false;
    }
    return true;
  }

  void _onAddMemberPressed() {
    _addNewMember();
  }

  void _submitAllMembers() async {
    setState(() => isLoading = true);
    bool allSuccess = true;
    int savedCount = 0;

    for (var i = 0; i < memberControllers.length; i++) {
      final success = await _saveMember(i);
      if (!success) {
        allSuccess = false;
        break;
      }
      savedCount++;
    }

    setState(() => isLoading = false);
    if (allSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Successfully added $savedCount member${savedCount != 1 ? 's' : ''}'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    }
  }

  Widget _buildDropdownField(String label, TextEditingController controller) {
    const genderOptions = ['Male', 'Female', 'Other'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        onChanged: (value) {
          if (value != null) {
            controller.text = value;
          }
        },
        items: genderOptions.map((gender) {
          return DropdownMenuItem(
            value: gender,
            child: Text(gender),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: Colors.grey[850],
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildMemberFields(int index) {
    final controllers = memberControllers[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(index == 0 ? "Head of Family" : "Member ${index + 1}",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                if (memberControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        memberControllers.removeAt(index);
                      });
                    },
                  )
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField("Name *", controllers['name']!),
            _buildDropdownField("Gender", controllers['gender']!),
            _buildDatePickerField(
                "DOB", controllers['dob']!, controllers['age']!),
            _buildTextField("Age", controllers['age']!,
                inputType: TextInputType.number),
            if (index > 0) ...[
              _buildRelationDropdown("Relation *", controllers['relation']!),
            ],
            _buildTextField("Address", controllers['address']!),
            _buildTextField("Phone", controllers['phone']!,
                inputType: TextInputType.phone),
            _buildTextField("Email", controllers['email']!,
                inputType: TextInputType.emailAddress),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        items: ['Male', 'Female', 'Other']
            .map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                ))
            .toList(),
        onChanged: (value) {
          controller.text = value!;
        },
        dropdownColor: Colors.grey[900],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(
      String label,
      TextEditingController dobController,
      TextEditingController ageController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            builder: (context, child) => Theme(
              data: ThemeData.dark(),
              child: child!,
            ),
          );

          if (picked != null) {
            final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
            dobController.text = formattedDate;

            // 🧮 Auto-calculate age
            final today = DateTime.now();
            int age = today.year - picked.year;
            if (today.month < picked.month ||
                (today.month == picked.month && today.day < picked.day)) {
              age--;
            }
            ageController.text = age.toString();
          }
        },
        child: AbsorbPointer(
          child: TextField(
            controller: dobController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelationDropdown(
      String label, TextEditingController controller) {
    const relationOptions = [
      'Father',
      'Mother',
      'Son',
      'Daughter',
      'Wife',
      'Husband',
      'Brother',
      'Sister',
      'Grandfather',
      'Grandmother',
      'Uncle',
      'Aunt',
      'Relative'
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        onChanged: (value) {
          if (value != null) {
            controller.text = value;
          }
        },
        items: relationOptions.map((relation) {
          return DropdownMenuItem(
            value: relation,
            child: Text(relation),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: Colors.grey[850],
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Add Family Members"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  ...List.generate(
                      memberControllers.length, _buildMemberFields),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _onAddMemberPressed,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Member"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitAllMembers,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Save All"),
                  ),
                ],
              ),
            ),
    );
  }
}
