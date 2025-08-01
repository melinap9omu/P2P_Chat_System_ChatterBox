// lib/verify_code_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:p2p_chat/services/api_service.dart';                   // 👈 update path
import 'login_page.dart';

class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({super.key, required this.number});
  final String number;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final api = ApiService();
    final res = await api.verifyResetCode(
      number: widget.number,
      code: _codeCtrl.text.trim(),
      newPassword: _pwdCtrl.text,
    );
    setState(() => _loading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Verification failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text('Verify Code', style: GoogleFonts.almarai(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Code sent to +977‑${widget.number}', style: GoogleFonts.almarai(color: Colors.white70)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _codeCtrl,
                maxLength: 4,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _input('4‑digit code'),
                validator: (v) => v == null || v.length != 4 ? 'Enter 4‑digit code' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwdCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _input('New password (min 8)'),
                validator: (v) => v != null && v.length >= 8 ? null : 'Min 8 chars',
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loading ? null : _reset,
                style: _btnStyle,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text('Reset Password', style: GoogleFonts.almarai(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  ButtonStyle get _btnStyle => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6B3A92),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}
