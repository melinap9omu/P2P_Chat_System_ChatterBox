class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String phoneNo;
  final String email;
  final String hashPassword;
  final String? publicKeyPem;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNo,
    required this.email,
    required this.hashPassword,
    this.publicKeyPem,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      firstName: json['FirstName'],
      lastName: json['LastName'],
      phoneNo: json['PhoneNo'],
      email: json['email'],
      hashPassword: json['hashPassword'],
      publicKeyPem: json['publicKeyPem'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'FirstName': firstName,
      'LastName': lastName,
      'PhoneNo': phoneNo,
      'email': email,
      'hashPassword': hashPassword,
      'publicKeyPem': publicKeyPem,
    };
  }
}