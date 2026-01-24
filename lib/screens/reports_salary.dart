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
          userSalary[userId] = {
            'totalSalary': (data['totalSalary'] is num) ? data['totalSalary'].toDouble() : double.tryParse(data['totalSalary']?.toString() ?? '') ?? 0.0,
            'totalHours': (data['totalHours'] is num) ? data['totalHours'].toDouble() : double.tryParse(data['totalHours']?.toString() ?? '') ?? 0.0,
            'hourlyRate': (data['hourlyRate'] is num) ? data['hourlyRate'].toDouble() : double.tryParse(data['hourlyRate']?.toString() ?? '') ?? 0.0,
            'dailyBreakdown': (data['dailyBreakdown'] is List) ? data['dailyBreakdown'] : [],
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

  /// ================= UI COMPONENTS =================

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
                    'Total Salary',
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

            ...((salary['dailyBreakdown'] ?? []) as List).map((d) {
              final date = DateTime.tryParse(d['date'] ?? '');
              final hours = (d['hours'] ?? d['workedHours'] ?? 0);
              final hoursDouble = (hours is num) ? hours.toDouble() : double.tryParse(hours.toString()) ?? 0.0;
              final salaryVal = (d['salary'] ?? 0);
              final salaryDouble = (salaryVal is num) ? salaryVal.toDouble() : double.tryParse(salaryVal.toString()) ?? 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date != null
                              ? dateFmt.format(date)
                              : '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hoursDouble.toStringAsFixed(1)} hrs',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      currency.format(salaryDouble),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
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
