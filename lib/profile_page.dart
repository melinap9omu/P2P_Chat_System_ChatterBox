import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'chat_page.dart';
import 'login_page.dart';
import 'change_password_page.dart';
import 'setting_page.dart';

class ProfilePage extends StatefulWidget {
  final String currentUserid;
  final String currentUsername;

  const ProfilePage({
    super.key,
    required this.currentUserid,
    required this.currentUsername,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage(); // Fetch from backend on load
  }

  /// ✅ Fetch Profile Image from Backend
  Future<void> _fetchProfileImage() async {
    final url = Uri.parse("http://localhost:8080/user/image?userId=${widget.currentUserid}");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        _profileImageBytes = response.bodyBytes; // Directly store bytes
      });
    } else {
      print("❌ Failed to fetch image: ${response.statusCode}");
    }
  }

  /// ✅ Pick Image and Upload to Backend
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse("http://localhost:8080/user/image"),
    )
      ..fields['userId'] = widget.currentUserid
      ..files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      print("✅ Image uploaded successfully");
      _fetchProfileImage(); // Refresh after upload
    } else {
      print("❌ Upload failed: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    const selectedIndex = 2;
    final labels = ['Chat', 'Friends', 'Profile'];
    final icons = [Icons.chat_bubble_outline, Icons.group_outlined, Icons.person_outline];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 25, 25, 25),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Profile', style: GoogleFonts.almarai(fontSize: 24, color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _pickAndUploadImage, // Tap avatar to change image
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[800],
                backgroundImage: _profileImageBytes != null
                    ? MemoryImage(_profileImageBytes!) // ✅ From backend
                    : const AssetImage('assets/profile.jpg') as ImageProvider,
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.currentUsername,
                style: GoogleFonts.almarai(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(widget.currentUsername,
                style: GoogleFonts.almarai(fontSize: 14, color: Colors.white60)),
            const SizedBox(height: 30),
            ProfileOption(icon: Icons.edit, label: 'Edit Profile', onTap: _pickAndUploadImage),
            ProfileOption(icon: Icons.lock_outline, label: 'Change Password', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
            }),
            ProfileOption(icon: Icons.settings, label: 'App Settings', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            }),
            ProfileOption(icon: Icons.logout, label: 'Log Out', onTap: () {
              _showLogoutDialog(context);
            }),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, selectedIndex, labels, icons),
    );
  }

  /// ✅ Logout Dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Confirm Logout', style: GoogleFonts.almarai(color: Colors.white)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('No', style: TextStyle(color: Colors.white60))),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  /// ✅ Bottom Navigation Bar
  Widget _buildBottomNavBar(BuildContext context, int selectedIndex, List<String> labels, List<IconData> icons) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(color: Color.fromARGB(255, 25, 25, 25)),
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
              children: List.generate(3, (index) {
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    if (index == 0) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            currentUserid: widget.currentUserid,
                            currentUsername: widget.currentUsername,
                            onLogout: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      );
                    } else if (index == 1) {
                      print('Friends tab tapped (Not implemented)');
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
                            color: isSelected ? const Color.fromARGB(255, 98, 48, 139) : Colors.transparent,
                          ),
                          child: Icon(icons[index], color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(labels[index], style: GoogleFonts.almarai(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ProfileOption({required this.icon, required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: GoogleFonts.almarai(color: Colors.white, fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: onTap,
    );
  }
}
