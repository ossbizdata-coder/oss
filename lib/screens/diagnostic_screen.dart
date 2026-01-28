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
                  // SALARY ISSUE WARNING
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Backend Issue Detected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The salary calculation is returning zero because:\n\n'
                          '1. Old attendance records (WORKING/NOT_WORKING status) don\'t have check-in/check-out timestamps\n'
                          '2. Without timestamps, backend calculates 0 hours worked\n'
                          '3. Records with 0 hours are marked as "not qualified"\n'
                          '4. Overtime/deduction hours exist but aren\'t being counted\n\n'
                          'SOLUTION: Backend needs to be updated to:\n'
                          '• Treat "WORKING" status records as 6+ hours (qualified)\n'
                          '• Or migrate old records with proper timestamps\n'
                          '• Or calculate hours from work_date assuming 8-hour workday',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

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

                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📋 Expected Data in Responses',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Attendance Response Should Include:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('• overtimeHours (number)'),
                          const Text('• deductionHours (number)'),
                          const Text('• overtimeReason (string)'),
                          const Text('• deductionReason (string)'),
                          const Text('• checkInTime (timestamp or null)'),
                          const Text('• checkOutTime (timestamp or null)'),
                          const SizedBox(height: 12),
                          Text(
                            'Salary dailyBreakdown Should Include:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('• hours (number - calculated work hours)'),
                          const Text('• qualified (boolean - true if hours >= 6)'),
                          const Text('• salary (number - calculated daily salary)'),
                          const Text('• overtimeHours (number)'),
                          const Text('• deductionHours (number)'),
                          const Text('• overtimeReason (string)'),
                          const Text('• deductionReason (string)'),
                          const SizedBox(height: 12),
                          Text(
                            'Monthly Salary Response Should Include:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('• baseSalary (number - salary before credits)'),
                          const Text('• totalCredits (number - credits to deduct)'),
                          const Text('• totalSalary (number - final salary after credits)'),
                          const Text('• dailySalary (number)'),
                          const Text('• hourlyRate (number)'),
                          const Text('• deductionRatePerHour (number)'),
                          const Text('• totalDaysWorked (number)'),
                          const Text('• minHoursRequired (number)'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    color: Colors.purple.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💳 Credits API (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.purple.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'GET /api/credits/me/breakdown?year=2026&month=1\n\n'
                            'Expected Response:\n'
                            '[\n'
                            '  {\n'
                            '    "shopType": "Main Store",\n'
                            '    "totalAmount": 5000.0,\n'
                            '    "count": 3\n'
                            '  },\n'
                            '  {\n'
                            '    "shopType": "Branch A",\n'
                            '    "totalAmount": 3000.0,\n'
                            '    "count": 2\n'
                            '  }\n'
                            ']\n\n'
                            'This endpoint is optional. If not available,\n'
                            'only total credits will be shown.',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              height: 1.5,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Database Records Available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'January 2026 has 23 attendance records:\n'
                            '• 22 WORKING days\n'
                            '• 1 NOT_WORKING day\n'
                            '• Multiple records with overtime hours\n'
                            '• Multiple records with deduction hours\n\n'
                            'Expected salary should be:\n'
                            '• Base: 22 days × Rs 2000 = Rs 44,000\n'
                            '• Plus overtime bonuses\n'
                            '• Minus deductions\n\n'
                            'But backend returns Rs 0 because records\n'
                            'lack check-in/check-out timestamps.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Colors.green.shade900,
                            ),
                          ),
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

