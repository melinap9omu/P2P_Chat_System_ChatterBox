import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
            // Profile Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/profile.jpg'), // Replace with your asset
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(height: 16),
            // User Name
            Text(
              'Your name',
              style: GoogleFonts.almarai(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Email
            Text(
              'dinisha@example.com',
              style: GoogleFonts.almarai(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 30),

            // Profile Settings Options
            ProfileOption(icon: Icons.edit, label: 'Edit Profile'),
            ProfileOption(icon: Icons.lock_outline, label: 'Change Password'),
            ProfileOption(icon: Icons.settings, label: 'App Settings'),
            ProfileOption(icon: Icons.logout, label: 'Log Out'),
          ],
        ),
      ),
    );
  }
}

class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;

  const ProfileOption({required this.icon, required this.label, super.key});

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
      onTap: () {
        // Add navigation or action here
      },
    );
  }
}
