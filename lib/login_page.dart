import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:p2p_chat/forget_password_page.dart';
import 'package:p2p_chat/services/API_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'chat_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool rememberMe = false;

  @override
  void dispose() {
    _numberController.dispose();
    _passwordController.dispose();
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

                  // Email Field
                  TextFormField(
                    controller: _numberController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      hintText: 'Number',
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
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

// Forgot Password Button
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
        color: const Color.fromARGB(255, 225, 178, 47),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

                  // Remember Me
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        activeColor: const Color.fromARGB(255, 251, 173, 64),
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
                  const SizedBox(height: 40),


                  // Login Button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color.fromARGB(255, 92, 41, 132),
                    ),
                    child: ElevatedButton(
             onPressed: () async {
if (_formKey.currentState!.validate()) {
  final api = ApiService(); // use consistent variable name
final result = await api.login(
  number: _numberController.text,
  password: _passwordController.text,
);

   print("Login result: $result"); // Debug print

print("Result type: ${result.runtimeType}");
print("Keys in result: ${result.keys}");

if (result['success'] == true) {
  final prefs = await SharedPreferences.getInstance();

  final user = result['user'];
  print("User data from server: $user");
  print("User map keys: ${user?.keys}");

  if (user == null) {
    print("User is null!");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid user data from server.')),
    );
    return;
  }

final userId = user['number']; // 👈 convert String to int
  final firstName = user['first_name'] ?? '';
  final lastName = user['last_name'] ?? '';
  final fullName = '$firstName $lastName'.trim();

  print("User ID: $userId");
  print("Full Name: $fullName");

  await prefs.setString('user_name', fullName);
await prefs.setString('user_number', user['number']); // leave as string


  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ChatPage(
 currentUserid:user['number'],
         currentUsername: fullName,
        onLogout: () async {
          await prefs.clear();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        },
      ),
    ),
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result['message'] ?? 'Login failed')),
  );
}

  }
},

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

                  // Sign Up Link
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
