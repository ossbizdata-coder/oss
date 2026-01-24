import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String attendanceResponse = 'Not loaded';
  String salaryResponse = 'Not loaded';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      setState(() {
        attendanceResponse = 'No token found';
        salaryResponse = 'No token found';
        loading = false;
      });
      return;
    }

    // Test attendance API
    try {
      final attRes = await http.get(
        Uri.parse("http://74.208.132.78/api/attendance/today"),
        headers: {"Authorization": "Bearer $token"},
      );

      final attData = jsonDecode(attRes.body);
      setState(() {
        attendanceResponse = JsonEncoder.withIndent('  ').convert(attData);
      });

      print("DEBUG Attendance API Response:");
      print(attendanceResponse);
    } catch (e) {
      setState(() => attendanceResponse = 'Error: $e');
    }

    // Test salary API
    try {
      final now = DateTime.now();
      final salRes = await http.get(
        Uri.parse("http://74.208.132.78/api/salary/me/monthly?year=${now.year}&month=${now.month}"),
        headers: {"Authorization": "Bearer $token"},
      );

      final salData = jsonDecode(salRes.body);
      setState(() {
        salaryResponse = JsonEncoder.withIndent('  ').convert(salData);
      });

      print("DEBUG Salary API Response:");
      print(salaryResponse);
    } catch (e) {
      setState(() => salaryResponse = 'Error: $e');
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Diagnostic'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GET /api/attendance/today',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      attendanceResponse,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'GET /api/salary/me/monthly',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      salaryResponse,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✅ Check if attendance response includes:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('• overtimeHours'),
                          Text('• deductionHours'),
                          Text('• overtimeReason'),
                          Text('• deductionReason'),
                          SizedBox(height: 16),
                          Text(
                            '✅ Check if salary dailyBreakdown includes:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('• overtimeHours'),
                          Text('• deductionHours'),
                          Text('• overtimeReason'),
                          Text('• deductionReason'),
                          Text('• qualified'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

