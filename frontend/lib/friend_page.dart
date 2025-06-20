import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FriendPage extends StatelessWidget {
  const FriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Friends',
          style: GoogleFonts.almarai(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'You have no friends yet.',
          style: GoogleFonts.almarai(
            fontSize: 16,
            color: Colors.white60,
          ),
        ),
      ),
    );
  }
}
