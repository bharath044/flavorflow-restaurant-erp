import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../services/auth_provider.dart';
import '../utils/responsive_helper.dart';

class PinResetScreen extends StatefulWidget {
  const PinResetScreen({super.key});

  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends State<PinResetScreen> {
  final adminPinCtrl = TextEditingController();
  final newPinCtrl = TextEditingController();
  final confirmPinCtrl = TextEditingController();

  UserRole selectedRole = UserRole.admin;

  bool verified = false;
  String? error;

  bool showAdminPin = false;
  bool showNewPin = false;
  bool showConfirmPin = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final size = MediaQuery.sizeOf(context);
    final cardWidth = ResponsiveHelper.responsiveValue<double>(
      context,
      mobile: size.width,
      tablet: 500,
      desktop: 500,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Change PIN (Admin)"),
        backgroundColor: const Color(0xFFFF6A00),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ================= ADMIN VERIFY =================
                if (!verified) ...[
                  const Text(
                    "Verify Admin PIN",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter current admin pin to continue",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: adminPinCtrl,
                    obscureText: !showAdminPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: "Admin PIN",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showAdminPin
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showAdminPin = !showAdminPin),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6A00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (auth.verifyAdminPin(adminPinCtrl.text.trim())) {
                          setState(() {
                            verified = true;
                            error = null;
                          });
                        } else {
                          setState(() => error = "Invalid Admin PIN");
                        }
                      },
                      child: const Text("VERIFY & CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]

                // ================= CHANGE PIN =================
                else ...[
                  const Text(
                    "Update User PIN",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Set a new 4-digit security PIN",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // ROLE SELECT (ADMIN INCLUDED)
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: "Select Role",
                      border: OutlineInputBorder(),
                    ),
                    items: UserRole.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (r) => setState(() => selectedRole = r!),
                  ),

                  const SizedBox(height: 16),

                  // NEW PIN
                  TextField(
                    controller: newPinCtrl,
                    obscureText: !showNewPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: "New PIN",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showNewPin
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showNewPin = !showNewPin),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CONFIRM PIN
                  TextField(
                    controller: confirmPinCtrl,
                    obscureText: !showConfirmPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: "Confirm PIN",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPin
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showConfirmPin = !showConfirmPin),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6A00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (newPinCtrl.text.length != 4) {
                          setState(() => error = "PIN must be 4 digits");
                          return;
                        }

                        if (newPinCtrl.text != confirmPinCtrl.text) {
                          setState(() => error = "PINs do not match");
                          return;
                        }

                        auth.resetPin(
                          role: selectedRole,
                          newPin: newPinCtrl.text.trim(),
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "${selectedRole.name.toUpperCase()} PIN updated successfully",
                            ),
                          ),
                        );

                        Navigator.pop(context);
                      },
                      child: const Text("UPDATE PIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],

                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
