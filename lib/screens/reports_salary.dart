import 'dart:convert';

import 'package:OSS/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsSalaryScreen extends StatefulWidget {
  const ReportsSalaryScreen({super.key});

  @override
  State<ReportsSalaryScreen> createState() => _ReportsSalaryScreenState();
}

class _ReportsSalaryScreenState extends State<ReportsSalaryScreen> {
  List users = [];
  Map<int, dynamic> userSalary = {};
  bool loading = true;
  String? error;

  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
  final dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    fetchSalaryForAllUsers();
  }

  Future<void> fetchSalaryForAllUsers() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString("role");
      final token = prefs.getString("token");

      if (role != "SUPERADMIN") {
        setState(() {
          error = "Access denied: Super Admins only";
          loading = false;
        });
        return;
      }

      final usersRes = await http.get(
        Uri.parse('http://74.208.132.78/api/users'),
        headers: token != null ? {"Authorization": "Bearer $token"} : {},
      );

      if (usersRes.statusCode != 200) {
        setState(() {
          error = 'Failed to load users';
          loading = false;
        });
        return;
      }

      users = jsonDecode(usersRes.body);

      final allowedUserIds = [1, 7, 8, 9, 47];
      users = users.where((user) => allowedUserIds.contains(user['id'])).toList();

      final now = DateTime(selectedYear, selectedMonth);
      userSalary.clear();

      await Future.wait(users.map((user) async {
        final userId = user['id'];

        final res = await http.get(
          Uri.parse(
              'http://74.208.132.78/api/salary/user/$userId/monthly?year=${now.year}&month=${now.month}'),
          headers: token != null ? {"Authorization": "Bearer $token"} : {},
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);

          double unpaidCredits = 0.0;
          try {
            final creditsRes = await http.get(
              Uri.parse('http://74.208.132.78/api/credits/user/$userId/summary'),
              headers: token != null ? {"Authorization": "Bearer $token"} : {},
            );

            if (creditsRes.statusCode == 200) {
              final creditsData = jsonDecode(creditsRes.body);
              unpaidCredits = (creditsData["unpaidCredits"] ?? 0).toDouble();
            }
          } catch (e) {
          }

          final totalSalary = (data['totalSalary'] is num)
              ? data['totalSalary'].toDouble()
              : double.tryParse(data['totalSalary']?.toString() ?? '') ?? 0.0;

          final baseSalary = data.containsKey('baseSalary')
              ? ((data['baseSalary'] is num) ? data['baseSalary'].toDouble() : double.tryParse(data['baseSalary']?.toString() ?? '') ?? 0.0)
              : totalSalary;

          final dailyBreakdown = (data['dailyBreakdown'] is List) ? data['dailyBreakdown'] : [];

          print('════════════════════════════════════════════════════════');
          print('💰 SALARY DATA for User $userId (${user['name']})');
          print('   - Month: $selectedYear-$selectedMonth');
          print('   - Daily Breakdown Records: ${dailyBreakdown.length}');

          if (dailyBreakdown.isNotEmpty) {
            print('   - First 5 records:');
            for (var i = 0; i < (dailyBreakdown.length > 5 ? 5 : dailyBreakdown.length); i++) {
              final record = dailyBreakdown[i];
              print('      ${i + 1}. Date: ${record['date']}, Status: ${record['status']}');
            }
          }
          print('════════════════════════════════════════════════════════');

          userSalary[userId] = {
            'baseSalary': baseSalary,
            'totalCredits': unpaidCredits,
            'totalSalary': baseSalary - unpaidCredits,
            'totalHours': (data['totalHours'] is num) ? data['totalHours'].toDouble() : double.tryParse(data['totalHours']?.toString() ?? '') ?? 0.0,
            'hourlyRate': (data['hourlyRate'] is num) ? data['hourlyRate'].toDouble() : double.tryParse(data['hourlyRate']?.toString() ?? '') ?? 0.0,
            'dailyBreakdown': dailyBreakdown,
          };
        } else {
          userSalary[userId] = {'error': 'Failed to load salary'};
        }
      }));

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth += offset;
      if (selectedMonth == 0) {
        selectedMonth = 12;
        selectedYear--;
      } else if (selectedMonth == 13) {
        selectedMonth = 1;
        selectedYear++;
      }
    });
    fetchSalaryForAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
    DateFormat.yMMMM().format(DateTime(selectedYear, selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Salary Report'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : fetchSalaryForAllUsers,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : users.isEmpty
          ? const Center(child: Text('No users found'))
          : Column(
        children: [
          /// MONTH SELECTOR
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => changeMonth(-1),
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => changeMonth(1),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final salary = userSalary[user['id']];

                return _userSalaryCard(user, salary);
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _userSalaryCard(dynamic user, dynamic salary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((Colors.black.a * 0.05).toInt()),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding:
          const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            user['name'] ?? 'N/A',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            user['email'] ?? '',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          children: salary == null || salary['error'] != null
              ? [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                salary?['error'] ?? 'No salary data',
                style: const TextStyle(color: Colors.red),
              ),
            )
          ]
              : [
            /// SUMMARY
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha((AppTheme.primary.a * 0.08).toInt()),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Salary (Final)',
                    style:
                    TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format((salary['totalSalary'] ?? 0).toDouble()),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if ((salary['totalCredits'] ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Base Salary',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        Text(
                          currency.format((salary['baseSalary'] ?? 0).toDouble()),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.remove_circle_outline, size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 4),
                            const Text(
                              'Unpaid Credits',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '- ${currency.format((salary['totalCredits'] ?? 0).toDouble())}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoChip(
                        Icons.schedule,
                        '${((salary['totalHours'] ?? 0) as num).toDouble().toStringAsFixed(2)} hrs',
                      ),
                      const SizedBox(width: 10),
                      _infoChip(
                        Icons.payments_outlined,
                        '${currency.format((salary['hourlyRate'] ?? 0).toDouble())}/hr',
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Daily Breakdown',
              style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            ...((salary['dailyBreakdown'] ?? []) as List).where((d) {
              final status = d['status'] ?? 'NOT_STARTED';
              return status != 'NOT_STARTED';
            }).map((d) {
              // Parse date - handle both timestamp (milliseconds) and string format
              DateTime? date;
              final dateValue = d['date'];

              if (dateValue != null) {
                if (dateValue is int) {
                  // Timestamp in milliseconds
                  date = DateTime.fromMillisecondsSinceEpoch(dateValue, isUtc: true);
                  print('📅 Parsed date from int timestamp: $dateValue → $date');
                } else if (dateValue is String) {
                  // Try parsing as timestamp first
                  final timestamp = int.tryParse(dateValue);
                  if (timestamp != null) {
                    date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
                    print('📅 Parsed date from string timestamp: $dateValue → $date');
                  } else {
                    // Parse as ISO date string
                    date = DateTime.tryParse(dateValue)?.toUtc();
                    print('📅 Parsed date from ISO string: $dateValue → $date');
                  }
                }
              } else {
                print('⚠️ Date value is null for record: $d');
              }

              final hours = (d['hours'] ?? d['workedHours'] ?? 0);
              final hoursDouble = (hours is num) ? hours.toDouble() : double.tryParse(hours.toString()) ?? 0.0;
              final salaryVal = (d['salary'] ?? 0);
              final salaryDouble = (salaryVal is num) ? salaryVal.toDouble() : double.tryParse(salaryVal.toString()) ?? 0.0;

              final overtime = (d['overtimeHours'] ?? 0);
              final overtimeDouble = (overtime is num) ? overtime.toDouble() : double.tryParse(overtime.toString()) ?? 0.0;
              final deduction = (d['deductionHours'] ?? 0);
              final deductionDouble = (deduction is num) ? deduction.toDouble() : double.tryParse(deduction.toString()) ?? 0.0;
              final overtimeReason = d['overtimeReason'];
              final deductionReason = d['deductionReason'];
              final status = d['status'] ?? 'UNKNOWN';

              final isWorked = (status == 'WORKING' || status == 'CHECKED_IN' || status == 'COMPLETED');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWorked ? Colors.green.shade200 : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isWorked ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: isWorked ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  date != null ? dateFmt.format(date) : '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isWorked
                                      ? '${hoursDouble.toStringAsFixed(1)} hrs'
                                      : 'Not Worked',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          currency.format(salaryDouble),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isWorked ? Colors.green.shade900 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),

                    if (overtimeDouble > 0 || deductionDouble > 0) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      if (overtimeDouble > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Overtime: ${overtimeDouble.toStringAsFixed(1)} hrs × ${currency.format((salary['hourlyRate'] ?? 0).toDouble())}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (overtimeReason != null && overtimeReason.toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        overtimeReason.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                '+${currency.format(overtimeDouble * (salary['hourlyRate'] ?? 0).toDouble())}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (deductionDouble > 0) const SizedBox(height: 8),
                      ],

                      if (deductionDouble > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle_outline, size: 16, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Deduction: ${deductionDouble.toStringAsFixed(1)} hrs × ${currency.format((salary['hourlyRate'] ?? 0).toDouble())}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (deductionReason != null && deductionReason.toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        deductionReason.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                '-${currency.format(deductionDouble * (salary['hourlyRate'] ?? 0).toDouble())}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
