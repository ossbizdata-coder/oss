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
  double hourlyRate = 0;
  double deductionRatePerHour = 0;
  int totalDaysWorked = 0;
  double baseSalary = 0; // Salary before credits
  double totalCredits = 0; // Total credits to deduct
  double totalSalary = 0; // Final salary after credits
  double totalOvertimeHours = 0; // Total overtime hours
  double totalOvertimeAmount = 0; // Total overtime payment
  double totalDeductionHours = 0; // Total deduction hours
  double totalDeductionAmount = 0; // Total deduction amount
  List<dynamic> daily = [];
  List<dynamic> creditsBreakdown = []; // Credits by shop type

  @override
  void initState() {
    super.initState();
    fetchSalary();
  }

  Future<void> fetchCreditsBreakdown() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse(
          "http://74.208.132.78/api/credits/me/breakdown"
              "?year=$selectedYear&month=$selectedMonth",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (mounted) {
          setState(() {
            creditsBreakdown = List.from(data ?? []);
          });
        }
      } else {
        if (mounted) {
          setState(() => creditsBreakdown = []);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => creditsBreakdown = []);
      }
    }
  }

  Future<void> fetchSalary() async {
    setState(() {
      loading = true;
      daily = [];
      creditsBreakdown = [];
      baseSalary = 0;
      totalCredits = 0;
      totalSalary = 0;
      totalDaysWorked = 0;
      dailySalary = 0;
      hourlyRate = 0;
      deductionRatePerHour = 0;
      totalOvertimeHours = 0;
      totalOvertimeAmount = 0;
      totalDeductionHours = 0;
      totalDeductionAmount = 0;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      if (mounted) Navigator.pushReplacementNamed(context, "/login");
      return;
    }

    try {
      // ✅ Step 1: Fetch monthly salary data
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

        double unpaidCredits = 0.0;
        try {
          final creditsRes = await http.get(
            Uri.parse("http://74.208.132.78/api/credits/me/summary"),
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
          );

          if (creditsRes.statusCode == 200) {
            final creditsData = jsonDecode(creditsRes.body);
            unpaidCredits = (creditsData["unpaidCredits"] ?? 0).toDouble();
          }
        } catch (e) {
        }

        if (mounted) {
          setState(() {
            dailySalary = (data["dailySalary"] ?? 0).toDouble();
            hourlyRate = (data["hourlyRate"] ?? 0).toDouble();
            deductionRatePerHour = (data["deductionRatePerHour"] ?? 0).toDouble();
            totalDaysWorked = (data["totalDaysWorked"] ?? 0).toInt();

            totalCredits = unpaidCredits;

            baseSalary = (data["baseSalary"] ?? data["totalSalary"] ?? 0).toDouble();

            totalSalary = baseSalary - totalCredits;

            daily = List.from(data["dailyBreakdown"] ?? [])
              ..sort((a, b) =>
                  DateTime.parse(b["date"])
                      .compareTo(DateTime.parse(a["date"])));

            totalOvertimeHours = 0;
            totalDeductionHours = 0;
            for (var day in daily) {
              totalOvertimeHours += (day["overtimeHours"] ?? 0).toDouble();
              totalDeductionHours += (day["deductionHours"] ?? 0).toDouble();
            }

            totalOvertimeAmount = totalOvertimeHours * hourlyRate;
            totalDeductionAmount = totalDeductionHours * deductionRatePerHour;

            loading = false;
          });
        }

        if (totalCredits > 0) {
          await fetchCreditsBreakdown();
        }
      } else {
        if (mounted) {
          setState(() => loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load salary data: ${res.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading salary: $e")),
        );
      }
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
          : Column(
        children: [
          // MONTH SELECTOR (Fixed at top)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade200, width: 2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 28),
                      tooltip: 'Previous month',
                      onPressed: () => changeMonth(-1),
                    ),
                    Column(
                      children: [
                        Text(
                          monthLabel,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 28),
                      tooltip: 'Next month',
                      onPressed: () => changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // NAVIGATION HINT for current month with few days
                  if (selectedMonth == DateTime.now().month &&
                      selectedYear == DateTime.now().year &&
                      totalDaysWorked < 10)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Viewing current month. Click ← to see January 2025 with more work history',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

            // TOTAL SALARY CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Monthly Salary",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$totalDaysWorked days",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Rs ${totalSalary.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  // Show breakdown if credits exist
                  if (totalCredits > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white30),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Base Salary",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "Rs ${baseSalary.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
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
                            Icon(Icons.credit_card_outlined, size: 14, color: Colors.orange.shade300),
                            const SizedBox(width: 6),
                            Text(
                              "Credits",
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "- Rs ${totalCredits.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Colors.orange.shade300,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Show overtime and deduction totals if they exist
                  if (totalOvertimeHours > 0 || totalDeductionHours > 0) ...[
                    const Divider(color: Colors.white30),
                    const SizedBox(height: 8),
                  ],

                  if (totalOvertimeHours > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 6),
                            Text(
                              "Total Overtime (${totalOvertimeHours.toStringAsFixed(1)}h)",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "+ Rs ${totalOvertimeAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                  if (totalOvertimeHours > 0 && totalDeductionHours > 0)
                    const SizedBox(height: 6),

                  if (totalDeductionHours > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.remove_circle_outline, size: 14, color: Colors.orange.shade300),
                            const SizedBox(width: 6),
                            Text(
                              "Total Deductions (${totalDeductionHours.toStringAsFixed(1)}h)",
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "- Rs ${totalDeductionAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Colors.orange.shade300,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),


                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              "Daily Rate: ",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "Rs ${dailySalary.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline, size: 16, color: Colors.greenAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Overtime Rate: Rs ${hourlyRate.toStringAsFixed(0)}/hr",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange.shade300),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Deduction Rate: Rs ${deductionRatePerHour.toStringAsFixed(0)}/hr",
                                      style: TextStyle(
                                        color: Colors.orange.shade300,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),


            // INFO MESSAGE when no salary
            if (totalSalary == 0 && totalDaysWorked == 0)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "How to earn salary",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "• Check in when you start work\n"
                            "• Work at least 6 hours to qualify for daily salary (Rs ${dailySalary.toStringAsFixed(0)})\n"
                            "• Check out when you finish work\n"
                            "• Overtime hours will add bonus pay\n"
                            "• Your salary will appear here once you complete qualified work days",
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // DAILY BREAKDOWN
            if (daily.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No completed attendance records",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...daily.asMap().entries.map((entry) {
                final index = entry.key;
                final d = entry.value;

                  final date = DateFormat.yMMMd()
                      .format(DateTime.parse(d["date"]));
                  final status = d["status"] ?? "NOT_STARTED";
                  final salary = (d["salary"] ?? 0).toDouble();
                  final overtime = (d["overtimeHours"] ?? 0).toDouble();
                  final deduction = (d["deductionHours"] ?? 0).toDouble();
                  final overtimeReason = d["overtimeReason"];
                  final deductionReason = d["deductionReason"];

                  bool isWorking = (status == "CHECKED_IN" || status == "COMPLETED" || status == "WORKING");
                  bool isNotWorking = (status == "NOT_WORKING");
                  bool hasStatus = (status != "NOT_STARTED");
                  Color statusColor = isNotWorking ? Colors.red : (isWorking ? Colors.green : Colors.grey);
                  IconData statusIcon = isNotWorking ? Icons.cancel : (isWorking ? Icons.check_circle : Icons.help_outline);
                  String statusText = isNotWorking ? "Not working" : (isWorking ? "Worked" : "No record");

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                              child: Row(
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  // Show status badge inline next to date
                                  if (hasStatus) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            size: 12,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Rs ${salary.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (isWorking)
                                  Text(
                                    "Base: Rs ${dailySalary.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // Show overtime if any
                        if (overtime > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Overtime: ${overtime.toStringAsFixed(1)} hrs × Rs ${hourlyRate.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (overtimeReason != null &&
                                          overtimeReason.toString().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          overtimeReason,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.green.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  "+Rs ${(overtime * hourlyRate).toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Show deduction if any
                        if (deduction > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Deduction: ${deduction.toStringAsFixed(1)} hrs × Rs ${deductionRatePerHour.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (deductionReason != null &&
                                          deductionReason.toString().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          deductionReason,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.red.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  "-Rs ${(deduction * deductionRatePerHour).toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
                  const SizedBox(height: 16), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
