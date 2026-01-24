import 'package:flutter/material.dart';
import '../services/pin_storage.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';

class PinEntryScreen extends StatefulWidget {
  final VoidCallback onPinSuccess;
  const PinEntryScreen({required this.onPinSuccess, Key? key}) : super(key: key);

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  void _checkPin() async {
    final inputPin = _controller.text.trim();
    final savedPin = await PinStorage.getPin();
    if (inputPin == savedPin) {
      widget.onPinSuccess();
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter PIN'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await PinStorage.deletePin();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(height: 120),
              const SizedBox(height: 32),
              Container(
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
                      "Quick PIN Login",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Enter your PIN",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'Enter PIN',
                        errorText: _error,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      text: "Unlock",
                      onPressed: _checkPin,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
