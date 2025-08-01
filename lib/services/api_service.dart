import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String _baseUrl = 'https://2bfb0be202a2.ngrok-free.app';

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('❌ $_baseUrl$path → ${response.statusCode}');
      print('Body: ${response.body}');
      return {'success': false, 'message': 'Request failed'};
    }
  }

  // 🔐 LOGIN
  Future<Map<String, dynamic>> login({
    required String number,
    required String password,
  }) async {
    return _postJson('/login', {
      'number': number,
      'password': password,
    });
  }

  // 🧑‍💼 REGISTER
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String number,
    required String email,
    required String password,
    required String rePassword,
    required String publicKey,
  }) async {
    return _postJson('/register', {
      'firstname': firstName,
      'lastname': lastName,
      'number': number,
      'email': email,
      'password': password,
      'rePassword': rePassword,
      'publicKeyPem': publicKey,
    });
  }

  // 🔄 STEP 1: SEND RESET CODE
  Future<Map<String, dynamic>> sendResetCode(String number) async {
  final uri = Uri.parse("https://2bfb0be202a2.ngrok-free.app/forgetPassword");
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'action': 'send-code',
      'number': number,
    },
  );

  if (response.statusCode == 200) {
    try {
      final json = jsonDecode(response.body);
      return {
        'success': json['success'],
        'message': json['message'],
        'code': json['code'], // Optional: only if you return it from backend
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid server response format',
      };
    }
  } else {
    return {'success': false, 'message': 'Server error'};
  }
}


  // 🔄 STEP 2: VERIFY RESET CODE
 // api_service.dart
Future<Map<String, dynamic>> verifyResetCode({
  required String number,
  required String code,
  required String newPassword,
}) async {
  final uri = Uri.parse('https://2bfb0be202a2.ngrok-free.app/forgetPassword');

  final response = await http.post(
    uri,
    headers: {
      // The servlet reads standard form parameters, not JSON:
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {
      'action': 'resetPassword',   // 👈 matches your backend
      'number': number,
      'code': code,
      'newPassword': newPassword,
    },
  );

if (response.statusCode == 200) {
  final body = jsonDecode(response.body);
  return {
    'success': body['success'] == true,
    'message': body['message'],
  };
} else {
  return {'success': false, 'message': 'Server error'};
}

}
}
