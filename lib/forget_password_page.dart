import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:p2p_chat/services/api_service.dart';                    
import 'verify_code_page.dart'; 

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _numberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _submit() async {
    print('Submit button pressed');
  if (!_formKey.currentState!.validate()) return;

  final number = _numberController.text.trim();
  final api = ApiService();      
  try {
    final result = await api.sendResetCode(number);

    if (result['success'] == true) {
      print('Reset code: ${result['code']}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Code sent')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyCodePage(number: number)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to send code')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Network error: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          'Forgot Password',
          style: GoogleFonts.almarai(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Enter your number to reset your password',
                style: GoogleFonts.almarai(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _numberController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Number',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your number';
  }
final numberRegex = RegExp(r'^(98|97)\d{8}$'); // Accepts exactly 10 digits
  if (!numberRegex.hasMatch(value)) {
    return 'Enter a valid 10-digit number';
  }
  return null;
},

              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3A92),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Send Reset Link',
                  style: GoogleFonts.almarai(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}