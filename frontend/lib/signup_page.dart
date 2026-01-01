import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import '../crypto/rsa_key_manager.dart';
import 'chat_page.dart';
import '../services/API_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  // Image-related variables
  File? _selectedImage;
  String? _profileImageBase64;
  final ImagePicker _picker = ImagePicker();

  // Animation controllers
  late AnimationController _profileImageAnimationController;
  late Animation<double> _profileImageAnimation;

  @override
  void initState() {
    super.initState();
    _profileImageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _profileImageAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _profileImageAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _profileImageAnimationController.dispose();
    super.dispose();
  }

  // Method to pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final List<int> imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);

        setState(() {
          _selectedImage = imageFile;
          _profileImageBase64 = base64String;
        });

        // Animate profile image when changed
        _profileImageAnimationController.forward().then((_) {
          _profileImageAnimationController.reverse();
        });

        _showSnackBar('Profile image updated successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  // Show image picker options
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Wrap(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Select Profile Photo',
                    style: GoogleFonts.almarai(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8C5DB2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFF8C5DB2)),
                  ),
                  title: Text(
                    'Photo Library',
                    style: GoogleFonts.almarai(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Choose from gallery',
                    style: GoogleFonts.almarai(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8C5DB2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_camera, color: Color(0xFF8C5DB2)),
                  ),
                  title: Text(
                    'Camera',
                    style: GoogleFonts.almarai(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Take a new photo',
                    style: GoogleFonts.almarai(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_selectedImage != null) ...[
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                    title: Text(
                      'Remove Photo',
                      style: GoogleFonts.almarai(color: Colors.red),
                    ),
                    subtitle: Text(
                      'Use initials instead',
                      style: GoogleFonts.almarai(color: Colors.red.withOpacity(0.7), fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedImage = null;
                        _profileImageBase64 = null;
                      });
                      _showSnackBar('Profile image removed', Colors.orange);
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // Generate random color for initials
  Color _generateRandomColor() {
    final List<Color> colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
      const Color(0xFF96CEB4),
      const Color(0xFFFFEAA7),
      const Color(0xFFDDA0DD),
      const Color(0xFF98D8C8),
      const Color(0xFFF7DC6F),
      const Color(0xFFBB8FCE),
      const Color(0xFF85C1E9),
    ];
    return colors[Random().nextInt(colors.length)];
  }

  // Get user initials
  String _getUserInitials() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();

    return initials.isEmpty ? '?' : initials;
  }

  // Build profile image widget
  Widget _buildProfileImageWidget() {
    return AnimatedBuilder(
      animation: _profileImageAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _profileImageAnimation.value,
          child: GestureDetector(
            onTap: _showImagePickerOptions,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8C5DB2).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedImage != null
                          ? Colors.transparent
                          : _generateRandomColor(),
                    ),
                    child: _selectedImage != null
                        ? ClipOval(
                      child: Image.file(
                        _selectedImage!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Center(
                      child: Text(
                        _getUserInitials(),
                        style: GoogleFonts.almarai(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8C5DB2),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.almarai(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.almarai(color: Colors.white60),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match.', Colors.red);
      return;
    }

    print('DEBUG: Frontend sending firstName: ${_firstNameController.text}');
    print('DEBUG: Frontend sending lastName: ${_lastNameController.text}');
    print('DEBUG: Frontend sending email: ${_emailController.text}');
    print('DEBUG: Frontend sending phoneNo: ${_phoneNoController.text}');
    print('DEBUG: Frontend sending password: ${_passwordController.text.isEmpty ? "EMPTY" : _passwordController.text.length} characters');
    print('DEBUG: Frontend sending confirmPassword: ${_confirmPasswordController.text.isEmpty ? "EMPTY" : _confirmPasswordController.text.length} characters');
    print('DEBUG: Frontend sending profileImage: ${_profileImageBase64 != null ? "YES" : "NO"}');

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Register user with profile image
      final registerResult = await _apiService.registerUser(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNo: _phoneNoController.text,
        password: _passwordController.text,
        rePassword: _confirmPasswordController.text,
        profileImageBase64: _profileImageBase64, // Pass the base64 image
      );

      print('Register API Response: $registerResult');

      if (registerResult['success'] == true) {
        Map<String, dynamic>? userData;

        if (registerResult['data'] != null && registerResult['data']['user'] != null) {
          userData = registerResult['data']['user'] as Map<String, dynamic>;
          print('DEBUG: Using nested structure (data.user)');
        } else if (registerResult['user'] != null) {
          userData = registerResult['user'] as Map<String, dynamic>;
          print('DEBUG: Using direct structure (user)');
        }

        if (userData == null) {
          _showSnackBar('Registration successful, but user data is missing or malformed from response.', Colors.red);
          print('Backend response structure missing user data: $registerResult');
          return;
        }

        final int newUserId = int.tryParse(userData['id']?.toString() ?? '') ?? 0;
        final String username = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
        final String userEmail = _emailController.text;

        if (newUserId == 0) {
          _showSnackBar('Registration successful, but user ID missing or invalid from response.', Colors.red);
          print('Backend response user ID is 0 or missing: $userData');
          return;
        }
        print('DEBUG: Successfully parsed user data - ID: $newUserId, Username: $username');

        // Step 2: Generate and securely store RSA Key Pair using the new userId
        final keyPair = await RsaKeyManager.generateNewKeyPair(newUserId);
        final String publicKeyPem = RsaKeyConverter.encodePublicKeyToX509Base64(keyPair.publicKey);
        final String privateKeyPem = RsaKeyConverter.encodePrivateKeyToPkcs8Base64(keyPair.privateKey);
        print('Generation successful');

        // Step 3: Update the backend with the newly generated public key
        final updateKeyResult = await _apiService.updatePublicKey(
          userId: newUserId,
          publicKeyPem: publicKeyPem,
        );
        print('DEBUG: UpdateKey Response: $updateKeyResult');

        if (updateKeyResult['success'] == true) {
          _showSnackBar('Registration successful and public key updated!', Colors.green);

          // Save user data including profile info
          await _apiService.saveUserData(
            userId: newUserId.toString(),
            username: username,
            email: userEmail,
            publicKeyPem: publicKeyPem,
            privateKeyPem: privateKeyPem,
          );

          // Step 4: Navigate to ChatPage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                currentUserid: newUserId,
                currentUsername: username,
                currentUserEmail: userEmail,
                currentUserPublicKeyPem: publicKeyPem,
                currentUserPrivateKeyPem: privateKeyPem,
                onLogout: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                        (Route<dynamic> route) => false,
                  );
                },
              ),
            ),
          );
        } else {
          _showSnackBar(updateKeyResult['message'] ?? 'Public key update failed. Please try again.', Colors.red);
          print('Public Key Update Failed Response: $updateKeyResult');
        }
      } else {
        _showSnackBar(registerResult['message'] ?? 'Registration failed. Please try again.', Colors.red);
        print('Registration Failed Response: $registerResult');
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', Colors.red);
      print('Unexpected error during registration: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.almarai(color: Colors.white),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Create Account',
                      style: GoogleFonts.almarai(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join our secure P2P chat network',
                      style: GoogleFonts.almarai(
                        fontSize: 16,
                        color: Colors.white60,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Profile Image Section
                    Center(child: _buildProfileImageWidget()),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to add profile photo (optional)',
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Form Fields
                    _buildTextField(
                      controller: _firstNameController,
                      hintText: 'First name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter first name';
                        }
                        if (value.trim().length < 2) {
                          return 'First name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _lastNameController,
                      hintText: 'Last name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter last name';
                        }
                        if (value.trim().length < 2) {
                          return 'Last name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter email address';
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) return 'Enter valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _phoneNoController,
                      hintText: 'Phone number',
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
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white60,
                        ),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter password';
                        if (value.length < 8) return 'Password must be at least 8 characters';
                        if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                          return 'Password must contain uppercase, lowercase, and number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm password',
                      obscureText: !showConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white60,
                        ),
                        onPressed: () {
                          setState(() {
                            showConfirmPassword = !showConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Sign Up Button
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8C5DB2), Color(0xFF6B3A92)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8C5DB2).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          'Create Account',
                          style: GoogleFonts.almarai(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Terms and Privacy
                    Text(
                      'By creating an account, you agree to our Terms of Service and Privacy Policy',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}