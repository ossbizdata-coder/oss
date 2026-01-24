import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class IdeaOfTheWeekScreen extends StatefulWidget {
  const IdeaOfTheWeekScreen({super.key});

  @override
  State<IdeaOfTheWeekScreen> createState() => _IdeaOfTheWeekScreenState();
}

class _IdeaOfTheWeekScreenState extends State<IdeaOfTheWeekScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ideaController = TextEditingController();
  bool _loading = false;

  Future<void> _submitIdea() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      final ideaText = _ideaController.text.trim();
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
      try {
        final res = await http.post(
          Uri.parse('http://74.208.132.78/api/messages/idea'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: '{"message": "$ideaText", "userId": $userId}',
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 || res.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Idea submitted successfully")),
          );
          _ideaController.clear();
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to submit idea: ${res.body}")),
          );
        }
      } on TimeoutException {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request timed out. Please try again.")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Idea of the Week"),
        centerTitle: true,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
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
                "What is your new idea for coming week?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _ideaController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Type your idea here",
                  hintText: "Type your idea here...",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your idea";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitIdea,
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
