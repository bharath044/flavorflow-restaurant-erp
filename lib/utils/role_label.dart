import '../models/user_role.dart';

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.server:
      return "Server Login";

    case UserRole.kitchen:
      return "Kitchen Login";

    case UserRole.staff:
      return "Staff Login";

    case UserRole.admin:
      return "Admin Login";
  }
}
