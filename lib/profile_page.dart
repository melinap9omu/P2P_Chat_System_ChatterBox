import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_page.dart';
// import 'friend_page.dart'; // REMOVED: This import is no longer needed
import 'login_page.dart';
import 'change_password_page.dart';
import 'setting_page.dart';

class ProfilePage extends StatelessWidget {
  // Added currentUserid as a required parameter
  // This is needed because ChatPage now requires it.
  final int currentUserid;
  final String currentUsername;
  
  const ProfilePage({
    super.key,
     required this.currentUserid,
         required this.currentUsername,
});

  @override
  Widget build(BuildContext context) {
    // Keep selectedIndex as 2, as Profile is still the 3rd tab (index 2)
    const selectedIndex = 2;

    // Keep labels and icons as they were, to preserve the UI
    final List<String> labels = ['Chat', 'Friends', 'Profile'];
    final List<IconData> icons = [
      Icons.chat_bubble_outline,
      Icons.group_outlined, // Icon for 'Friends' tab remains
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
            CircleAvatar(
              radius: 50,
              backgroundImage: const AssetImage('assets/profile.jpg'),
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(height: 16),
            Text(
            currentUsername, // You might want to display the actual user name here
              style: GoogleFonts.almarai(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
             currentUsername,
// You might want to display the actual user email here
              style: GoogleFonts.almarai(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 30),
            ProfileOption(icon: Icons.edit, label: 'Edit Profile'),
            ProfileOption(icon: Icons.lock_outline, label: 'Change Password'),
            ProfileOption(icon: Icons.settings, label: 'App Settings'),
            ProfileOption(icon: Icons.logout, label: 'Log Out'),
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
                // List.generate(3, ...) remains unchanged to keep 3 tabs
                children: List.generate(3, (index) {
                  final isSelected = selectedIndex == index;
                  return GestureDetector(
                    onTap: () {
                      
                      if (index == 0) { // Chat tab
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ChatPage(
        currentUserid:currentUserid, // 👈 if constructor expects int
        currentUsername: currentUsername,
        onLogout: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        },
      ),
    ), // ✅ This closing bracket is misplaced
  ); // ✅ It should be here
}
     else if (index == 1) { // Friends tab
                        // REMOVED: Navigation to FriendPage
                        // You can add a print statement or a SnackBar here if you want feedback
                        print('Friends tab tapped, but FriendPage functionality is removed.');
     }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 3, // Remains divided by 3 for 3 tabs
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
        if (label == 'Edit Profile') {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1E1E1E),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera, color: Colors.white),
                    title: Text('Change Profile Picture',
                        style: GoogleFonts.almarai(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Change picture clicked')),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: Text('Delete Profile',
                        style: GoogleFonts.almarai(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: Text('Delete Profile?',
                              style: GoogleFonts.almarai(color: Colors.white)),
                          content: const Text(
                            'Are you sure you want to permanently delete your profile?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Colors.white60)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile deleted')),
                                );
                              },
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        } else if (label == 'Change Password') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
          );
        } else if (label == 'App Settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        } else if (label == 'Log Out') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
          );
        }
      },
    );
  }
}