// lib/screens/profile_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../services/API_service.dart';
import 'chat_page.dart';
import 'login_page.dart';
import 'change_password_page.dart';
import 'setting_page.dart';

class ProfilePage extends StatefulWidget {
  final int currentUserid;
  final String currentUsername;
  final String currentUserEmail;
  final String currentUserPublicKeyPem;
  final String currentUserPrivateKeyPem;

  const ProfilePage({
    super.key,
    required this.currentUserid,
    required this.currentUsername,
    required this.currentUserEmail,
    required this.currentUserPrivateKeyPem,
    required this.currentUserPublicKeyPem
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  String _displayedEmail = '';
  Uint8List? _profileImageBytes; // Changed from URL to bytes
  bool _isLoadingImage = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _loadProfileImage();
  }

  // Method to load the user's email from shared preferences
  Future<void> _loadUserEmail() async {
    final email = await _apiService.getEmail();
    if (mounted) {
      setState(() {
        _displayedEmail = email ?? 'Email not found';
      });
    }
  }

  // Updated method to load profile image as bytes using authenticated Dio
  Future<void> _loadProfileImage() async {
    try {
      await _apiService.ensureInitialized();

      // Verify session first
      final sessionValid = await _apiService.verifySession();
      if (!sessionValid) {
        print('Session invalid, redirecting to login');
        _logout();
        return;
      }

      setState(() {
        _isLoadingImage = true;
        _profileImageBytes = null;
      });

      // Use Dio to fetch the image as bytes
      final response = await _apiService.dio.get(
        '/profile-image',
        queryParameters: {
          'userId': widget.currentUserid.toString(),
          't': DateTime.now().millisecondsSinceEpoch.toString(), // Cache busting
        },
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status! < 500,
          headers: {
            'Cache-Control': 'no-cache',
          },
        ),
      );

      print("DEBUG: Profile image response status: ${response.statusCode}");

      if (mounted) {
        if (response.statusCode == 200 && response.data != null) {
          setState(() {
            _profileImageBytes = Uint8List.fromList(response.data);
            _isLoadingImage = false;
          });
          print("DEBUG: Profile image loaded successfully");
        } else {
          setState(() {
            _profileImageBytes = null;
            _isLoadingImage = false;
          });
          print("DEBUG: No profile image found (status: ${response.statusCode})");
        }
      }

    } catch (e) {
      print('Error loading profile image: $e');
      if (mounted) {
        setState(() {
          _profileImageBytes = null;
          _isLoadingImage = false;
        });
      }
    }
  }

  // Method to handle image upload
  Future<void> _handleImageUpload() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show options for camera or gallery
      final imageSource = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: GoogleFonts.almarai(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: Text(
                  'Camera',
                  style: GoogleFonts.almarai(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: Text(
                  'Gallery',
                  style: GoogleFonts.almarai(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (imageSource == null) return;

      // Pick image
      final XFile? pickedFile = await picker.pickImage(
        source: imageSource,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Verify session before upload
      final sessionValid = await _apiService.verifySession();
      if (!sessionValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        _logout();
        return;
      }

      setState(() {
        _isUploadingImage = true;
      });

      // Upload image
      final File imageFile = File(pickedFile.path);
      print("DEBUG: About to upload image file: ${imageFile.path}");
      print("DEBUG: File exists: ${imageFile.existsSync()}");
      print("DEBUG: File size: ${await imageFile.length()} bytes");

      final result = await _apiService.uploadProfileImageMultipart(imageFile);

      print("DEBUG: Upload result: $result");

      if (mounted) {
        if (result['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully!'),
              backgroundColor: Color.fromARGB(255, 98, 48, 139),
            ),
          );

          // Wait a moment for the server to process, then refresh
          await Future.delayed(const Duration(milliseconds: 1000));
          _loadProfileImage();
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update profile image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } on DioException catch (e) {
      if (mounted) {
        String errorMessage = 'Error uploading image: ${e.message}';
        if (e.response != null && e.response!.data != null) {
          final responseData = e.response!.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // Method to handle image deletion
  Future<void> _handleImageDelete() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Delete Profile Picture',
            style: GoogleFonts.almarai(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete your profile picture?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Call API to delete profile image
      final result = await _apiService.deleteProfileImage();

      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture deleted successfully!'),
            backgroundColor: Color.fromARGB(255, 98, 48, 139),
          ),
        );

        // Refresh the profile image
        _loadProfileImage();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete profile picture'),
            backgroundColor: Colors.red,
          ),
        );
      }

    } on DioException catch (e) {
      if (mounted) {
        String errorMessage = 'Error deleting image: ${e.message}';
        if (e.response != null && e.response!.data != null) {
          final responseData = e.response!.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // Method to show profile picture options
  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Picture Options',
              style: GoogleFonts.almarai(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: Text(
                'Change Profile Picture',
                style: GoogleFonts.almarai(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleImageUpload();
              },
            ),
            if (_profileImageBytes != null) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(
                  'Delete Profile Picture',
                  style: GoogleFonts.almarai(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageDelete();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- LOGOUT FUNCTIONALITY ---
  Future<void> _logout() async {
    // Clear user data from SharedPreferences
    await _apiService.clearUserData();

    // Navigate back to the LoginPage and remove all other routes from the stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const selectedIndex = 2;

    final List<String> labels = ['Chat', 'Profile'];
    final List<IconData> icons = [
      Icons.chat_bubble_outline,
      Icons.person_outline
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 25, 25, 25),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.almarai(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Profile Image with loading state and tap functionality
            _buildProfileImage(),
            const SizedBox(height: 16),
            Text(
              widget.currentUsername,
              style: GoogleFonts.almarai(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _displayedEmail,
              style: GoogleFonts.almarai(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 30),
            ProfileOption(
              icon: Icons.edit,
              label: 'Edit Profile',
              onTap: _showProfilePictureOptions,
            ),
            ProfileOption(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
                  );
                }
            ),
            ProfileOption(
                icon: Icons.settings,
                label: 'App Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                }
            ),
            ProfileOption(
              icon: Icons.logout,
              label: 'Log Out',
              onTap: _logout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 25, 25, 25),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 70,
                color: const Color.fromARGB(255, 14, 14, 14),
              ),
            ),
            Positioned(
              top: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(2, (index) {
                  final isSelected = selectedIndex == index;
                  return GestureDetector(
                    onTap: () {
                      if (index == 0) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              currentUserid: widget.currentUserid,
                              currentUsername: widget.currentUsername,
                              currentUserEmail: widget.currentUserEmail,
                              currentUserPublicKeyPem: '',
                              currentUserPrivateKeyPem: '',
                              onLogout: _logout,
                            ),
                          ),
                        );
                      }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? const Color.fromARGB(255, 98, 48, 139)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              icons[index],
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[index],
                            style: GoogleFonts.almarai(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated build profile image method to use Image.memory instead of Image.network
  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _showProfilePictureOptions,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[800],
            child: _isLoadingImage || _isUploadingImage
                ? const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            )
                : _profileImageBytes != null
                ? ClipOval(
              child: Image.memory(
                _profileImageBytes!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error displaying profile image: $error');
                  return Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.grey[400],
                  );
                },
              ),
            )
                : Icon(
              Icons.person,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          // Camera icon overlay
          if (!_isLoadingImage && !_isUploadingImage)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 98, 48, 139),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ProfileOption widget
class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: GoogleFonts.almarai(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: onTap,
    );
  }
}