class UserModel {
  final String id;
  final String username;
  final String email;
  final String? token;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      token: token ?? json['token']?.toString(),
    );
  }

  factory UserModel.empty({String? token}) {
    return UserModel(id: '', username: '', email: '', token: token);
  }
}
