// lib/model/user.dart

import 'dart:convert';

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String fullName;

  // Make these optional as they are not always included in the online user list payload
  final String? phoneNo;
  final String? publicKeyPem;

  // We'll also make hashPassword optional, assuming it's only relevant during login/registration
  final String? hashPassword;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.fullName,
    this.phoneNo,
    this.hashPassword,
    this.publicKeyPem,
  });

  // Updated factory constructor to handle incoming JSON from both API and WebSocket.
  factory User.fromJson(Map<String, dynamic> json) {
    // Determine the key names based on the incoming JSON structure.
    // The WebSocket online users update uses 'firstname' and 'lastname'.
    // The login API uses 'firstName' and 'lastName' (which may be inconsistent based on previous snippets, but we'll use the lowercase keys from the OnlineUserData model in Kotlin as seen in the logs).

    // Ensure all required fields are non-null using null-aware operators or default values if needed.
    final int id = json['id'] as int;
    final String email = json['email'] as String? ?? 'N/A';

    // Handle inconsistencies between 'firstname'/'firstName' and 'lastname'/'lastName'
    final String firstName = (json['firstname'] as String? ?? json['firstName'] as String? ?? 'Unknown');
    final String lastName = (json['lastname'] as String? ?? json['lastName'] as String? ?? 'Unknown');

    // Online users data includes 'fullName', while the login data might not.
    final String fullName = json['fullName'] as String? ?? '$firstName $lastName';

    return User(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      fullName: fullName,
      // Optional fields, safely cast to nullable types
      phoneNo: json['phoneNo'] as String?,
      hashPassword: json['hashPassword'] as String?,
      publicKeyPem: json['publicKeyPem'] as String?,
    );
  }

  // Conversion back to JSON for sending data (e.g., PUT or POST requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // We send the keys consistent with the Kotlin User model if needed,
      // but rely on 'firstName' and 'lastName' for JSON output consistency.
      'firstName': firstName,
      'lastName': lastName,
      'phoneNo': phoneNo,
      'email': email,
      'hashPassword': hashPassword,
      'publicKeyPem': publicKeyPem,
      'fullName': fullName,
    };
  }
}