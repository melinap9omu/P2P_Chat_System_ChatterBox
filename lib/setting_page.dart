import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _buildSettingTile(Icons.notifications, 'Notifications'),
          _buildSettingTile(Icons.language, 'Language'),
          _buildSettingTile(Icons.privacy_tip_outlined, 'Privacy Policy'),
          _buildSettingTile(Icons.help_outline, 'Help & Support'),
        ],
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: GoogleFonts.almarai(color: Colors.white),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
      onTap: () {
        // Add navigation or toggle here
      },
    );
  }
}
