// lib/screens/login_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/API_service.dart';
import '../crypto/rsa_key_manager.dart';

import 'signup_page.dart';
import 'chat_page.dart';
import 'forgot_password_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool rememberMe = false;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final loginResult = await _apiService.loginUser(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (loginResult['success']) {
        print('Login successful for: ${_emailController.text}');

        Map<String, dynamic>? userData;
        if (loginResult['user'] != null) {
          userData = loginResult['user'] as Map<String, dynamic>;
          print('DEBUG: Using direct structure (user)');
        }

        if (userData == null) {
          _showSnackBar('Login successful, but user data is missing or malformed from response.', Colors.red);
          print('Backend response structure missing user data after login: $loginResult');
          return;
        }

        // Test session validity before proceeding
        final sessionValid = await _apiService.testSession();
        if (!sessionValid) {
          _showSnackBar('Login successful, but session is invalid. Please try again.', Colors.orange);
          print('Session validation failed after login');
          return;
        }

        final int currentUserId = userData['id'] as int;
        final String currentUsername = '${userData['firstName']} ${userData['lastName']}';
        final String currentUserEmail = userData['email'] as String;

        final keyPair = await RsaKeyManager.generateNewKeyPair(currentUserId);

        final String currentUserPublicKeyPem = RsaKeyConverter.encodePublicKeyToX509Base64(keyPair.publicKey);
        final String currentUserPrivateKeyPem = RsaKeyConverter.encodePrivateKeyToPkcs8Base64(keyPair.privateKey);

        final String? backendPublicKeyPem = userData['publicKeyPem'];
        bool needsPublicKeyUpdate = backendPublicKeyPem == null ||
            backendPublicKeyPem.isEmpty ||
            backendPublicKeyPem != currentUserPublicKeyPem;

        if (needsPublicKeyUpdate) {
          print('Public key on backend is different or missing for user $currentUserId. Updating...');
          final updateKeyResult = await _apiService.updatePublicKey(
            userId: currentUserId,
            publicKeyPem: currentUserPublicKeyPem,
          );

          if (updateKeyResult['success']) {
            _showSnackBar('Login successful and public key synchronized!', Colors.green);
          } else {
            _showSnackBar(updateKeyResult['message'] ?? 'Login successful, but failed to update public key on server.', Colors.orange);
          }
        } else {
          _showSnackBar('Login successful!', Colors.green);
        }

        // Save user data locally
        await _apiService.saveUserData(
          userId: currentUserId.toString(),
          username: currentUsername,
          email: currentUserEmail,
          publicKeyPem: currentUserPublicKeyPem,
          privateKeyPem: currentUserPrivateKeyPem,
        );

        // Navigate to chat page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              currentUserid: currentUserId,
              currentUsername: currentUsername,
              currentUserEmail: currentUserEmail,
              currentUserPublicKeyPem: currentUserPublicKeyPem,
              currentUserPrivateKeyPem: currentUserPrivateKeyPem,
              onLogout: () async {
                await _apiService.clearUserData();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
          ),
        );
      } else {
        _showSnackBar(loginResult['message'] ?? 'Login failed. Please check your credentials.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', Colors.red);
      print('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in',
                    style: GoogleFonts.almarai(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      hintText: 'Email',
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF8C5DB2), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF8C5DB2), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      } else if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.almarai(
                          color: Colors.white70,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        activeColor: const Color(0xFF8C5DB2),
                        checkColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white70,
                          width: 2,
                        ),
                        onChanged: (value) {
                          setState(() {
                            rememberMe = value ?? false;
                          });
                        },
                      ),
                      Text(
                        'Remember me',
                        style: GoogleFonts.almarai(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color.fromARGB(255, 92, 41, 132),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        minimumSize: const Size(250, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'Login',
                        style: GoogleFonts.almarai(
                          fontSize: 27,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don’t have an account? ",
                        style: GoogleFonts.almarai(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: GoogleFonts.almarai(
                            color: const Color.fromARGB(255, 225, 178, 47),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}