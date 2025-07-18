import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers for text fields
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final dobController = TextEditingController();
  final locationController = TextEditingController();

  final Map<String, TextEditingController> socialLinks = {
    'Discord': TextEditingController(),
    'Instagram': TextEditingController(),
    'LinkedIn': TextEditingController(),
    'Twitter': TextEditingController(),
  };

  // State variables
  String? selectedGender;
  String? profileImageUrl;
  File? _profileImageFile;
  bool _isLoading = true;
  bool _isUpdating = false;
  String _message = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    dobController.dispose();
    locationController.dispose();
    for (var controller in socialLinks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Loads initial data, first from cache, then from network.
  Future<void> _loadInitialData() async {
    await _loadUserFromCache();
    await _fetchUserDetails();
  }

  /// Populates all controllers and state variables from a user data map.
  void _populateControllersFromData(Map<String, dynamic> user) {
    if (!mounted) return;

    setState(() {
      nameController.text = user['name']?.toString() ?? '';
      phoneController.text = user['phone']?.toString() ?? '';
      emailController.text = user['email']?.toString() ?? '';

      // Fixed DOB parsing logic
      final rawDob = user['dob']?.toString();
      if (rawDob != null &&
          rawDob.isNotEmpty &&
          rawDob.toLowerCase() != 'null') {
        dobController.text = _formatDateForDisplay(rawDob);
      } else {
        dobController.text = '';
      }

      locationController.text = user['location']?.toString() ?? '';

      final gender = user['gender']?.toString();
      if (gender != null &&
          gender.isNotEmpty &&
          gender.toLowerCase() != 'null') {
        selectedGender = gender;
      } else {
        selectedGender = null;
      }

      final path = user['profile_picture']?.toString() ?? '';
      if (path.isNotEmpty) {
        profileImageUrl = path.startsWith('http') ? path : '$baseUrl/$path';
      }

      // Handle social links - check both possible formats
      final socialLinksData = user['socialLinks'] ?? user['social_links'] ?? {};
      socialLinks.forEach((key, controller) {
        final value = socialLinksData[key.toLowerCase()]?.toString() ?? '';
        controller.text = value;
      });
    });
  }

  /// Helper method to format date for display
  String _formatDateForDisplay(String dateString) {
    try {
      DateTime date;

      // Handle ISO format with timezone (from server)
      if (dateString.contains('T') &&
          (dateString.contains('Z') || dateString.contains('+'))) {
        // Parse ISO datetime and convert to local date
        final parsed = DateTime.parse(dateString);
        final localDate = parsed.toLocal();
        date = DateTime(localDate.year, localDate.month, localDate.day);
      }
      // Handle simple date formats
      else if (dateString.contains('-')) {
        if (dateString.split('-')[0].length == 4) {
          // yyyy-MM-dd format - parse as local date
          final parts = dateString.split('-');
          date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          // dd-MM-yyyy format - parse as local date
          final parts = dateString.split('-');
          date = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else if (dateString.contains('/')) {
        // Try dd/MM/yyyy format - parse as local date
        final parts = dateString.split('/');
        date = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        // Try ISO format but convert to local
        final parsed = DateTime.parse(dateString);
        date = DateTime(parsed.year, parsed.month, parsed.day);
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $dateString - $e');
      return dateString; // Return original if parsing fails
    }
  }

  /// Helper method to parse date from display format
  DateTime? _parseDateFromDisplay(String dateString) {
    if (dateString.isEmpty) return null;

    try {
      // Parse dd-MM-yyyy as local date to avoid timezone issues
      final parts = dateString.split('-');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]) // day
            );
      }
      return null;
    } catch (e) {
      print('Could not parse date: $dateString - $e');
      return null;
    }
  }

  /// Fetches user details from the server.
  Future<void> _fetchUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Making request to: $baseUrl/api/users/me');

    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'User not logged in';
          _isError = true;
        });
      }
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        if (res.statusCode == 200) {
          final responseData = jsonDecode(res.body);
          final user = responseData['user'] ?? responseData;

          // Cache the user data
          await prefs.setString('cached_user', jsonEncode(user));

          // Only populate fields if this is the initial load, not after an update
          if (_isLoading) {
            _populateControllersFromData(user);
          }
        } else {
          _setMessage('Failed to load user data.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _setMessage('Error fetching details: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Loads user data from local cache if available.
  Future<void> _loadUserFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('cached_user');
    if (userJson != null) {
      try {
        final user = jsonDecode(userJson);
        _populateControllersFromData(user);
      } catch (e) {
        print('Error loading cached user: $e');
      }
    }
  }

  /// Handles profile update logic.
  Future<void> _updateProfile() async {
    if (nameController.text.trim().isEmpty) {
      _setMessage('Name is required', isError: true);
      return;
    }

    setState(() {
      _isUpdating = true;
      _message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        _setMessage('User not logged in', isError: true);
        return;
      }

      // Fixed DOB formatting for server
      String formattedDob = '';
      if (dobController.text.trim().isNotEmpty) {
        final parsedDate = _parseDateFromDisplay(dobController.text.trim());
        if (parsedDate != null) {
          formattedDob = DateFormat('yyyy-MM-dd').format(parsedDate);
        }
      }

      final body = jsonEncode({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'gender': selectedGender ?? '',
        'dob': formattedDob,
        'location': locationController.text.trim(),
        'socialLinks': {
          for (var entry in socialLinks.entries)
            entry.key.toLowerCase(): entry.value.text.trim()
        },
      });

      final res = await http.patch(
        Uri.parse('$baseUrl/api/users/edit-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (mounted) {
        if (res.statusCode == 200) {
          // Update cached user data with current form values
          final updatedUser = {
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'email': emailController.text.trim(),
            'gender': selectedGender ?? '',
            'dob': formattedDob,
            'location': locationController.text.trim(),
            'profile_picture': profileImageUrl ?? '',
            'socialLinks': {
              for (var entry in socialLinks.entries)
                entry.key.toLowerCase(): entry.value.text.trim()
            },
          };

          await prefs.setString('cached_user', jsonEncode(updatedUser));

          _showSnackbar('Profile updated successfully!', isError: false);

          // Refresh data from server in background without affecting UI
          _fetchUserDetails();
        } else {
          final data = jsonDecode(res.body);
          _setMessage(data['message'] ?? 'Update failed', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _setMessage('Error updating profile: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// Handles picking an image from the gallery and uploading it.
  Future<void> _pickAndUploadImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final imageFile = File(picked.path);
    setState(() {
      _profileImageFile = imageFile;
      _isUpdating = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _setMessage('User not logged in', isError: true);
      setState(() => _isUpdating = false);
      return;
    }

    final uri = Uri.parse('$baseUrl/api/users/upload-profile-picture');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('profile', imageFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);

        // Update profile image URL
        final newImageUrl = data['profile_picture'] ?? data['url'];
        if (newImageUrl != null) {
          setState(() {
            profileImageUrl = newImageUrl.startsWith('http')
                ? newImageUrl
                : '$baseUrl/$newImageUrl';
          });
        }

        _showSnackbar('Profile picture updated!', isError: false);
      } else {
        _setMessage('Failed to upload profile picture', isError: true);
      }
    } catch (e) {
      _setMessage('Upload error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// Shows the date picker dialog and updates the DOB controller.
  Future<void> _selectDate() async {
    print('DOB field tapped ✅');

    DateTime initialDate;

    // Try to parse existing value or use a reasonable default
    if (dobController.text.isNotEmpty) {
      final parsedDate = _parseDateFromDisplay(dobController.text);
      if (parsedDate != null) {
        initialDate = parsedDate;
      } else {
        initialDate = DateTime(2000, 1, 1);
      }
    } else {
      initialDate = DateTime(2000, 1, 1);
    }

    // Ensure the initial date is within valid range
    final now = DateTime.now();
    final firstDate = DateTime(1900);

    if (initialDate.isAfter(now)) {
      initialDate = now;
    } else if (initialDate.isBefore(firstDate)) {
      initialDate = DateTime(2000, 1, 1);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  // --- Helper Methods for UI ---

  void _setMessage(String msg, {required bool isError}) {
    if (mounted) {
      setState(() {
        _message = msg;
        _isError = isError;
      });
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileAvatar(),
                  const SizedBox(height: 20),
                  _buildTextField(
                      label: "Full Name", controller: nameController),
                  _buildTextField(
                    label: "Phone Number",
                    controller: phoneController,
                    inputType: TextInputType.phone,
                  ),
                  _buildTextField(
                    label: "Email",
                    controller: emailController,
                    inputType: TextInputType.emailAddress,
                  ),
                  _buildGenderDropdown(),
                  _buildTextField(
                    label: "Date of Birth",
                    controller: dobController,
                    readOnly: true,
                    onTap: _selectDate,
                  ),
                  _buildTextField(
                      label: "Location", controller: locationController),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text("Socials",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                  ),
                  ...socialLinks.entries.map((entry) => _buildTextField(
                      label: "${entry.key} Link", controller: entry.value)),
                  const SizedBox(height: 20),
                  if (_message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isError
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isError ? Colors.red : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: _isError ? Colors.red : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        (_isLoading || _isUpdating) ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text("SAVE"),
                  ),
                ],
              ),
            ),
    );
  }

  /// Widget for the profile picture avatar
  Widget _buildProfileAvatar() {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _isUpdating ? null : _pickAndUploadImage,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[800],
              backgroundImage: _profileImageFile != null
                  ? FileImage(_profileImageFile!)
                  : (profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? NetworkImage(profileImageUrl!)
                      : null) as ImageProvider?,
              child: _profileImageFile == null &&
                      (profileImageUrl == null || profileImageUrl!.isEmpty)
                  ? const Icon(Icons.camera_alt,
                      color: Colors.white70, size: 30)
                  : null,
            ),
          ),
          if (_isUpdating)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Generic widget for a text input field
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType inputType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        readOnly: readOnly,
        onTap: onTap,
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

  /// Widget for the gender selection dropdown
  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DropdownButtonFormField<String>(
        value: selectedGender,
        hint: const Text(
          'Select Gender',
          style: TextStyle(color: Colors.white70),
        ),
        items: ['Male', 'Female', 'Other']
            .map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(
                    gender,
                    style: const TextStyle(color: Colors.white),
                  ),
                ))
            .toList(),
        onChanged: (val) => setState(() => selectedGender = val),
        decoration: InputDecoration(
          labelText: "Gender",
          filled: true,
          fillColor: Colors.grey[900],
          labelStyle: const TextStyle(color: Colors.white70),
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
        dropdownColor: Colors.grey[900],
        style: const TextStyle(color: Colors.white),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
      ),
    );
  }
}
