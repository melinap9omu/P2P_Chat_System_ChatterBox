import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';
import 'services/api_service.dart';
import 'login_page.dart';
import 'package:crypton/crypton.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';



class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool showPassword = false;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
final TextEditingController _numberController = TextEditingController();
  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _numberController.dispose();
        _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B3A92), Color(0xFF080808)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign Up',
                    style: GoogleFonts.almarai(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _firstNameController,
                    hintText: 'First name',
                    validator: (value) => value!.isEmpty ? 'Enter first name' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _lastNameController,
                    hintText: 'Last name',
                    validator: (value) => value!.isEmpty ? 'Enter last name' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter email';
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _numberController,
                    hintText: 'number',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter phone number';
                      if (value.length < 7) return 'Enter valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: !showPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter password';
                      if (value.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Re-enter password',
                    obscureText: !showPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Checkbox(
                        value: showPassword,
                        onChanged: (value) {
                          setState(() {
                            showPassword = value ?? false;
                          });
                        },
                        side: const BorderSide(color: Colors.white70),
                        activeColor: const Color(0xFF8C5DB2),
                        checkColor: Colors.white,
                      ),
                      Text(
                        'Show password',
                        style: GoogleFonts.almarai(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color.fromARGB(255, 92, 41, 132),
                    ),
                    child: ElevatedButton(
                      onPressed: _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        minimumSize: const Size(250, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Sign up',
                        style: GoogleFonts.almarai(
                          fontSize: 27,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  void _registerUser() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
       final keyPair = RSAKeypair.fromRandom();
    final publicKeyPem = keyPair.publicKey.toPEM();
    final privateKeyPem = keyPair.privateKey.toPEM();

 // ✅ Debug print
    print("✅ Public Key (PEM):\n$publicKeyPem");
    print("🔐 Private Key (PEM):\n$privateKeyPem");

     const storage = FlutterSecureStorage();
      await storage.write(key: 'publicKey', value: publicKeyPem);
    await storage.write(key: 'privateKey', value: privateKeyPem);

      final api = ApiService();
      final result = await api.register(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        number: _numberController.text, // ✅ matches backend field
        email: _emailController.text,
        password: _passwordController.text,
        rePassword: _confirmPasswordController.text,
         publicKey: publicKeyPem,
      );

     if (result['success'] == true) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Registration successful!')),
  );

  await Future.delayed(const Duration(milliseconds: 500));
  Navigator.pushReplacement(
    context,
 MaterialPageRoute(builder: (context) => const LoginPage()),  );



      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Registration failed')),
        );
      }
    } catch (e) {
        print("❌ Error during registration: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

