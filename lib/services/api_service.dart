import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ LOGIN Function
  Future<Map<String, dynamic>> login({
    required String number,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('https://194d-2404-7c00-49-7549-690a-6623-9164-7d79.ngrok-free.app/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'number': number, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'success': false, 'message': 'Login failed'};
    }
  }

  // ✅ REGISTER Function
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String number,
    required String email,
    required String password,
    required String rePassword,
     required String publicKey,
  }) async {
    final response = await http.post(
      Uri.parse('https://194d-2404-7c00-49-7549-690a-6623-9164-7d79.ngrok-free.app/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstname': firstName,
        'lastname': lastName,
        'number': number,
        'email': email,
        'password': password,
        'rePassword': rePassword,
          'publicKeyPem': publicKey,
      }),
    );

    if (response.statusCode == 200) {
  return jsonDecode(response.body);
} else {
  print("Status Code: ${response.statusCode}");
  print("Response Body: ${response.body}");
  return {'success': false, 'message': 'Registration failed'};
}
  }
}
