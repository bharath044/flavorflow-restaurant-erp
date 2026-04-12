class User {
  final String id;
  final String username;
  final String pin;
  final String role;
  final int updatedAt;
  final int isSynced;

  User({
    required this.id,
    required this.username,
    required this.pin,
    required this.role,
    required this.updatedAt,
    required this.isSynced,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'pin': pin,
        'role': role,
        'updated_at': updatedAt,
        'is_synced': isSynced,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'],
        username: map['username'],
        pin: map['pin'],
        role: map['role'],
        updatedAt: map['updated_at'],
        isSynced: map['is_synced'],
      );
}
