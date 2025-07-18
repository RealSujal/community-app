import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../constants/constants.dart';

class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final inviteCodeController = TextEditingController();
  bool isLoading = false;
  String message = '';
  bool isError = false;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  void handleJoinCommunity() async {
    setState(() {
      isLoading = true;
      isError = false;
      message = '';
    });

    final token = await getToken();
    if (token == null) {
      setState(() {
        isLoading = false;
        isError = true;
        message = 'User not logged in.';
      });
      return;
    }

    final url = Uri.parse('$baseUrl/api/communities/join-community');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'invite_code': inviteCodeController.text.trim().toUpperCase(),
        }),
      );
      print("⚠️ Response status: ${response.statusCode}");
      print("⚠️ Response body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          message = '${data['message']}';
        });

        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() {
          isError = true;
          message = data['message'] ?? 'Failed to join';
        });
      }
    } catch (e) {
      setState(() {
        isError = true;
        message = 'Error: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Join Community'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Enter 6-digit Invite Code',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),

            /// ✅ PIN Code Invite Field
            PinCodeTextField(
              appContext: context,
              length: 6,
              obscureText: false,
              animationType: AnimationType.fade,
              controller: inviteCodeController,
              keyboardType: TextInputType.text,
              autoFocus: true,
              autoDismissKeyboard: true,
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                final upperCase = value.toUpperCase();

                if (value != upperCase) {
                  inviteCodeController.value = TextEditingValue(
                    text: upperCase,
                    selection:
                        TextSelection.collapsed(offset: upperCase.length),
                  );
                }
                if (isError && value.isNotEmpty) {
                  setState(() {
                    isError = false;
                    message = '';
                  });
                }
              },
              onCompleted: (_) {
                // Optional auto-submit when full
              },
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 60,
                fieldWidth: 48,
                activeColor: isError ? Colors.red : Colors.white,
                selectedColor: Colors.white70,
                inactiveColor: Colors.grey,
                activeFillColor: Colors.grey.shade900,
                inactiveFillColor: Colors.grey.shade800,
                selectedFillColor: Colors.grey.shade700,
              ),
              backgroundColor: Colors.black,
              enableActiveFill: true,
            ),

            const SizedBox(height: 24),

            /// ✅ Join Button
            ElevatedButton(
              onPressed: isLoading ? null : handleJoinCommunity,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2)
                  : const Text(
                      'JOIN COMMUNITY',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),

            const SizedBox(height: 20),

            /// ✅ Feedback message
            if (message.isNotEmpty)
              Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.redAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
