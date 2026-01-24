import 'package:flutter/material.dart';
import 'package:OSS/services/auth_services.dart';
import '../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController cpCtrl = TextEditingController();
  bool loading = false;

  void register() async {
    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      return _msg("All fields are required");
    }
    if (passCtrl.text != cpCtrl.text) {
      return _msg("Passwords do not match");
    }

    setState(() => loading = true);
    final success = await AuthService.register(
      nameCtrl.text.trim(),
      emailCtrl.text.trim(),
      passCtrl.text.trim(),
    );
    setState(() => loading = false);

    if (success) {
      _msg("Registered successfully. Login to continue.");
      Navigator.pop(context); // Go back to login screen
    } else {
      _msg("Registration failed. Email may already be in use.");
    }
  }

  void _msg(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: "Full Name"),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(hintText: "Email Address"),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: "Password"),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: cpCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: "Confirm Password"),
                ),
                const SizedBox(height: 22),

                loading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(
                  text: "Register",
                  onPressed: register,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
