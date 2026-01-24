import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalaryDetailsScreen extends StatefulWidget {
  const SalaryDetailsScreen({super.key});

  @override
  State<SalaryDetailsScreen> createState() => _SalaryDetailsScreenState();
}

class _SalaryDetailsScreenState extends State<SalaryDetailsScreen> {
  bool loading = true;

  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  double dailySalary = 0;
  double deductionRatePerHour = 0;
  int totalDaysWorked = 0;
  double totalSalary = 0;
  List<dynamic> daily = [];

  @override
  void initState() {
    super.initState();
    fetchSalary();
  }

  Future<void> fetchSalary() async {
    setState(() {
      loading = true;
      daily = [];          // ✅ CLEAR OLD MONTH DATA
      totalSalary = 0;
      totalDaysWorked = 0;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    final res = await http.get(
      Uri.parse(
        "http://74.208.132.78/api/salary/me/monthly"
            "?year=$selectedYear&month=$selectedMonth",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print("DEBUG Salary Response: $data");
      setState(() {
        dailySalary = (data["dailySalary"] ?? 0).toDouble();
        deductionRatePerHour = (data["deductionRatePerHour"] ?? 0).toDouble();
        totalDaysWorked = (data["totalDaysWorked"] ?? 0).toInt();
        totalSalary = (data["totalSalary"] ?? 0).toDouble();
        daily = List.from(data["dailyBreakdown"] ?? [])
          ..sort((a, b) =>
              DateTime.parse(b["date"])
                  .compareTo(DateTime.parse(a["date"])));
        loading = false;
      });
      print("DEBUG dailySalary: $dailySalary, deductionRate: $deductionRatePerHour");
    } else {
      print("DEBUG Salary API Error: ${res.statusCode} - ${res.body}");
      setState(() => loading = false);
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
    fetchSalary();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
    DateFormat.yMMMM().format(DateTime(selectedYear, selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Salary"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Use PinStorage to delete pin and log out
              // Import PinStorage if not already
              // ignore: use_build_context_synchronously
              await Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // MONTH SELECTOR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => changeMonth(-1),
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => changeMonth(1),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // TOTAL SALARY CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Salary",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Rs ${totalSalary.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$totalDaysWorked days • Rs ${dailySalary.toStringAsFixed(0)}/day",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Deduction rate: Rs ${deductionRatePerHour.toStringAsFixed(0)}/hr",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // DAILY BREAKDOWN
            Expanded(
              child: daily.isEmpty
                  ? const Center(
                child: Text(
                  "No completed attendance records",
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.separated(
                itemCount: daily.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final d = daily[index];
                  print("DEBUG Daily item $index: $d");

                  // Check if overtime/deduction fields exist
                  final hasOvertimeFields = d.containsKey("overtimeHours") &&
                                           d.containsKey("deductionHours");

                  if (!hasOvertimeFields && index == 0) {
                    print("⚠️ WARNING: Backend not returning overtime/deduction fields!");
                    print("⚠️ dailyBreakdown items should include: overtimeHours, deductionHours, overtimeReason, deductionReason");
                  }

                  final date = DateFormat.yMMMd()
                      .format(DateTime.parse(d["date"]));
                  final hours = (d["hours"] ?? 0).toDouble();
                  final salary = (d["salary"] ?? 0).toDouble();
                  final overtime = (d["overtimeHours"] ?? 0).toDouble();
                  final deduction = (d["deductionHours"] ?? 0).toDouble();
                  final overtimeReason = d["overtimeReason"];
                  final deductionReason = d["deductionReason"];
                  print("DEBUG Overtime: $overtime, Deduction: $deduction");

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((Colors.black.a * 0.05).toInt()),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${hours.toStringAsFixed(1)} hrs worked",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Show daily rate - ALWAYS VISIBLE FOR DEBUGGING
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Base: Rs ${dailySalary.toStringAsFixed(0)}/day",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Show deduction rate - ALWAYS VISIBLE FOR DEBUGGING
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "OT/Deduct: Rs ${deductionRatePerHour.toStringAsFixed(0)}/hr",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Rs ${salary.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),

                        // Show overtime if any
                        if (overtime > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Overtime: ${overtime.toStringAsFixed(1)} hrs",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                if (overtimeReason != null && overtimeReason.toString().isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    "($overtimeReason)",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Show deduction if any
                        if (deduction > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline,
                                  size: 14,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Deduction: ${deduction.toStringAsFixed(1)} hrs",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                if (deductionReason != null && deductionReason.toString().isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    "($deductionReason)",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
