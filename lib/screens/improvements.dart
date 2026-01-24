import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ImprovementsScreen extends StatefulWidget {
  const ImprovementsScreen({super.key});

  @override
  State<ImprovementsScreen> createState() => _ImprovementsScreenState();
}

class _ImprovementsScreenState extends State<ImprovementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _improvementController = TextEditingController();
  bool _loading = false;

  Future<void> _submitImprovement() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      final improvementText = _improvementController.text.trim();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      final token = prefs.getString('token');
      if (userId == null || token == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in")),
        );
        return;
      }
      final res = await http.post(
        Uri.parse('http://74.208.132.78/api/messages/improvement'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: '{"message": "$improvementText", "userId": $userId}',
      );
      setState(() => _loading = false);
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your suggestion has been sent to management")),
        );
        _improvementController.clear();
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit suggestion: ${res.body}")),
        );
      }
    }
  }

  @override
  void dispose() {
    _improvementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Improvements"),
        centerTitle: true,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Help OneStopDaily Improve",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _improvementController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Type your Suggestion here",
                  hintText: "Type your suggestion or improvement here...",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your suggestion";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitImprovement,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          "Submit",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
