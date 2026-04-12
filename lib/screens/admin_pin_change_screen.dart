import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/auth_provider.dart';
import '../utils/responsive_helper.dart';

class AdminPinChangeScreen extends StatefulWidget {
  const AdminPinChangeScreen({super.key});

  @override
  State<AdminPinChangeScreen> createState() =>
      _AdminPinChangeScreenState();
}

class _AdminPinChangeScreenState
    extends State<AdminPinChangeScreen> {
  final TextEditingController adminPinCtrl =
      TextEditingController();
  final TextEditingController newPinCtrl =
      TextEditingController();

  UserRole selectedRole = UserRole.staff;
  bool adminVerified = false;
  String? error;

  @override
  void dispose() {
    adminPinCtrl.dispose();
    newPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final cardWidth = ResponsiveHelper.responsiveValue<double>(
      context,
      mobile: double.infinity,
      tablet: 500,
      desktop: 500,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Change PIN (Admin)"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ================= ADMIN VERIFY =================
                if (!adminVerified) ...[
                  const Text(
                    "Verify Admin PIN",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: adminPinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: "Admin PIN",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (auth.verifyAdminPin(
                            adminPinCtrl.text.trim())) {
                          setState(() {
                            adminVerified = true;
                            error = null;
                          });
                        } else {
                          setState(() {
                            error = "Invalid Admin PIN";
                          });
                        }
                      },
                      child: const Text("VERIFY"),
                    ),
                  ),
                ]

                // ================= PIN CHANGE =================
                else ...[
                  const Text(
                    "Change PIN",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    items: UserRole.values
                        .where((r) => r != UserRole.admin)
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => selectedRole = val!),
                    decoration: const InputDecoration(
                      labelText: "Select Role",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: newPinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: "New PIN",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (newPinCtrl.text.length != 4) {
                          setState(() =>
                              error = "PIN must be 4 digits");
                          return;
                        }

                        await auth.resetPin(
                          role: selectedRole,
                          newPin: newPinCtrl.text.trim(),
                        );

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("PIN updated successfully"),
                          ),
                        );

                        Navigator.pop(context);
                      },
                      child: const Text("UPDATE PIN"),
                    ),
                  ),
                ],

                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
