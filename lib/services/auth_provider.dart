import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_role.dart';

class AuthProvider extends ChangeNotifier {
  /// ================= HIVE =================
  final Box box = Hive.box('auth');

  /// ================= STATE =================
  UserRole? _role;
  bool _isLoggedIn = false;
  String? _username;

  /// ================= GETTERS =================
  UserRole? get role => _role;
  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;

  bool get isAdmin => _role == UserRole.admin;
  bool get isStaff => _role == UserRole.staff;
  bool get isServer => _role == UserRole.server;
  bool get isKitchen => _role == UserRole.kitchen;

  /// ================= OLD PIN MAP (KEEP AS IS) =================
  final Map<UserRole, String> _pins = {
    UserRole.admin: '1234',
    UserRole.staff: '1111',
    UserRole.server: '2222',
    UserRole.kitchen: '3333',
  };

  /// ================= INIT =================
  AuthProvider() {
    _restoreSession();
    _loadPinsFromHive();
  }

  void _restoreSession() {
    final savedRole = box.get('logged_role');

    if (savedRole != null) {
      _role = UserRole.values.firstWhere(
        (r) => r.name == savedRole,
        orElse: () => UserRole.staff,
      );
      _isLoggedIn = true;
    } else {
      // 🔥 ENSURE CLEAN STATE
      _role = null;
      _isLoggedIn = false;
    }
  }

  void _loadPinsFromHive() {
    for (final role in UserRole.values) {
      final savedPin = box.get('${role.name}_pin');
      if (savedPin != null) {
        _pins[role] = savedPin;
      }
    }
  }

  // ================= ROLE SELECT =================
  void setRole(UserRole? role) {
    _role = role;
    _isLoggedIn = false;
    _username = null;
    notifyListeners();
  }

  // ================= PIN LOGIN =================
  bool loginWithPin(String pin) {
    if (_role == null) return false;

    if (_pins[_role] == pin) {
      _isLoggedIn = true;

      // 💾 Persist login
      box.put('logged_role', _role!.name);

      notifyListeners();
      return true;
    }
    return false;
  }

  // ================= ADMIN VERIFY =================
  bool verifyAdminPin(String pin) {
    return _pins[UserRole.admin] == pin;
  }

  // ================= SAVE PIN =================
  Future<void> savePin(String role, String newPin) async {
    await box.put('${role}_pin', newPin);
  }

  // ================= RESET PIN =================
  Future<void> resetPin({
    required UserRole role,
    required String newPin,
  }) async {
    _pins[role] = newPin;
    await savePin(role.name, newPin);
    notifyListeners();
  }

  // ================= DIRECT LOGIN =================
  void loginWithRole(UserRole role) {
    _role = role;
    _isLoggedIn = true;
    box.put('logged_role', role.name);
    notifyListeners();
  }

  // ================= LOGOUT (🔥 FINAL FIX) =================
  void logout() {
    _role = null;
    _username = null;
    _isLoggedIn = false;

    /// 🔥 CLEAR SESSION COMPLETELY
    box.delete('logged_role');

    notifyListeners();
  }
}
