class User {
  final int id;
  final int createdBy;
  final int userId;
  final int sbuId;
  final int status;
  final String name;
  final String token;
  final String email;
  final bool isSuccess;

  User({
    required this.id,
    required this.createdBy,
    required this.userId,
    required this.sbuId,
    required this.status,
    required this.name,
    required this.token,
    required this.email,
    required this.isSuccess,
  });

  // Parse from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      userId: json['userId'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      status: json['status'] ?? 0,
      name: json['name'] ?? '',
      token: json['token'] ?? '',
      email: json['email'] ?? '',
      isSuccess: json['isSuccess'] ?? false,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdBy': createdBy,
      'userId': userId,
      'sbuId': sbuId,
      'status': status,
      'name': name,
      'token': token,
      'email': email,
      'isSuccess': isSuccess,
    };
  }
}
