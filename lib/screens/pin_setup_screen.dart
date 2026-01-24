import 'package:flutter/material.dart';
import '../services/pin_storage.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({Key? key}) : super(key: key);

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _controller = TextEditingController();
  String? _error;

  void _savePin() async {
    final pin = _controller.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }
    try {
      await PinStorage.savePin(pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN saved successfully!')),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacementNamed(context, '/pin-entry');
      }
    } catch (e) {
      setState(() => _error = 'Failed to save PIN. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set PIN'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
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
                      "Set PIN",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).primaryColor,
                      ),
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
                      text: "Save PIN",
                      onPressed: _savePin,
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
