class User {

  final int id;
  final String firstname;
  final String lastname;
  final String phoneNo;
  final String email;




  User({required this.id,
    required this.firstname,
    required this.lastname,
    required this.phoneNo,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json){
    return User(
      id: json['id'] as int,
      firstname: json['firstName'] as String,
      lastname: json['lastName'] as String,
      phoneNo: json ['phoneNo'] as String,
      email: json['email'] as String,
    );
  }

  String get fullName=>'$firstname $lastname';

  Map<String, dynamic> toJson(){
    return{
  'id': id,
  'firstName': firstname,
  'lastName': lastname,
  'phoneNo': phoneNo,
  'email': email
  };
}
}
