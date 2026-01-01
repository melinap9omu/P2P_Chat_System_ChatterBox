import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'change_password_page.dart'; // Import your change password page

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.almarai(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _buildSettingTile(
            context,
            Icons.lock_outline,
            'Change Password',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          _buildSettingTile(context, Icons.notifications, 'Notifications'),
          _buildSettingTile(context, Icons.language, 'Language'),
          _buildSettingTile(context, Icons.privacy_tip_outlined, 'Privacy Policy'),
          _buildSettingTile(context, Icons.help_outline, 'Help & Support'),
        ],
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: GoogleFonts.almarai(color: Colors.white),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
      onTap: onTap ?? () {
        // Default action for other settings
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title feature coming soon!'),
            backgroundColor: const Color(0xFF622F8A),
          ),
        );
      },
    );
  }
}