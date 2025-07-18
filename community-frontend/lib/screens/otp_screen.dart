import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import '../constants/constants.dart';

class OtpScreen extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String password;

  const OtpScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  bool isError = false;
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    sendOtp(); // Send OTP automatically on screen load
  }

  Future<void> sendOtp() async {
    setState(() {
      isLoading = true;
      statusMessage = "Sending OTP...";
    });

    final url = Uri.parse('$baseUrl/auth/send-otp');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );
      final data = jsonDecode(res.body);
      setState(() {
        statusMessage = data['message'] ?? "OTP sent";
        isError = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = "Failed to send OTP";
        isError = true;
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> handleVerify() async {
    setState(() {
      isLoading = true;
      isError = false;
      statusMessage = "Verifying OTP...";
    });

    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': widget.name,
          'email': widget.email,
          'phone': widget.phone,
          'password': widget.password,
          'otp': otpController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() {
          statusMessage = data['message'] ?? "Registered";
        });
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          isError = true;
          statusMessage = data['message'] ?? 'Invalid OTP';
        });
      }
    } catch (e) {
      setState(() {
        isError = true;
        statusMessage = "Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Enter OTP", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "We’ve sent you a 4-digit code",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            PinCodeTextField(
              appContext: context,
              length: 4,
              controller: otpController,
              keyboardType: TextInputType.number,
              autoFocus: true,
              animationType: AnimationType.fade,
              enableActiveFill: true,
              textStyle: const TextStyle(color: Colors.white, fontSize: 20),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 60,
                fieldWidth: 50,
                activeColor: isError ? Colors.red : Colors.green,
                selectedColor: Colors.white,
                inactiveColor: Colors.grey,
                activeFillColor: Colors.black,
                inactiveFillColor: Colors.black,
                selectedFillColor: Colors.grey[900]!,
              ),
              onChanged: (val) {
                if (isError && val.isNotEmpty) {
                  setState(() {
                    isError = false;
                    statusMessage = '';
                  });
                }
              },
              onCompleted: (val) => handleVerify(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : handleVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("VERIFY", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Text(
              statusMessage,
              style: TextStyle(
                color: isError ? Colors.red : Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: isLoading ? null : sendOtp,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                foregroundColor: Colors.white,
              ),
              child: const Text("Resend OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
