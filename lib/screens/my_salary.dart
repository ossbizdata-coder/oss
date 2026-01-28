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

      print("DEBUG Credits Breakdown API: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("DEBUG Credits Breakdown Response: $data");

        if (mounted) {
          setState(() {
            creditsBreakdown = List.from(data ?? []);
          });
        }
      } else {
        print("DEBUG Credits Breakdown API Error: ${res.statusCode} - ${res.body}");
        // If endpoint doesn't exist, just continue without credits breakdown
        if (mounted) {
          setState(() => creditsBreakdown = []);
        }
      }
    } catch (e) {
      print("DEBUG Credits Breakdown API Exception: $e");
      // Fail silently - credits breakdown is optional
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
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      if (mounted) Navigator.pushReplacementNamed(context, "/login");
      return;
    }

    try {
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

      print("DEBUG Salary API: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("DEBUG Salary Response: $data");

        if (mounted) {
          setState(() {
            dailySalary = (data["dailySalary"] ?? 0).toDouble();
            hourlyRate = (data["hourlyRate"] ?? 0).toDouble();
            deductionRatePerHour = (data["deductionRatePerHour"] ?? 0).toDouble();
            totalDaysWorked = (data["totalDaysWorked"] ?? 0).toInt();

            // Handle new credits integration (backward compatible)
            if (data.containsKey("baseSalary")) {
              // New API with credits
              baseSalary = (data["baseSalary"] ?? 0).toDouble();
              totalCredits = (data["totalCredits"] ?? 0).toDouble();
              totalSalary = (data["totalSalary"] ?? 0).toDouble();
            } else {
              // Old API without credits
              baseSalary = (data["totalSalary"] ?? 0).toDouble();
              totalCredits = 0;
              totalSalary = baseSalary;
            }

            daily = List.from(data["dailyBreakdown"] ?? [])
              ..sort((a, b) =>
                  DateTime.parse(b["date"])
                      .compareTo(DateTime.parse(a["date"])));
            loading = false;
          });
        }
        print("DEBUG dailySalary: $dailySalary, hourlyRate: $hourlyRate, deductionRate: $deductionRatePerHour");
        print("DEBUG baseSalary: $baseSalary, totalCredits: $totalCredits, finalSalary: $totalSalary");

        // Fetch credits breakdown if user has credits
        if (totalCredits > 0) {
          await fetchCreditsBreakdown();
        }
      } else {
        print("DEBUG Salary API Error: ${res.statusCode} - ${res.body}");
        if (mounted) {
          setState(() => loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load salary data: ${res.statusCode}")),
          );
        }
      }
    } catch (e) {
      print("DEBUG Salary API Exception: $e");
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
                    "Monthly Salary",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
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
                            Icon(Icons.remove_circle_outline, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            const Text(
                              "Credits",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "- Rs ${totalCredits.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        "$totalDaysWorked working days",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.payments, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        "Daily: Rs ${dailySalary.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      Text(
                        "Overtime: Rs ${hourlyRate.toStringAsFixed(0)}/hr",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.remove_circle_outline, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        "Deduction: Rs ${deductionRatePerHour.toStringAsFixed(0)}/hr",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // CREDITS BREAKDOWN by shop type
            if (totalCredits > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.credit_card, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Credits Breakdown",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Show breakdown by shop type if available
                    if (creditsBreakdown.isNotEmpty)
                      ...creditsBreakdown.map((credit) {
                        final shopType = credit["shopType"] ?? "Unknown";
                        final amount = (credit["totalAmount"] ?? 0).toDouble();
                        final count = credit["count"] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "$shopType ($count transaction${count > 1 ? 's' : ''})",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "Rs ${amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      // Show total credits if breakdown not available
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Credits",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade800,
                            ),
                          ),
                          Text(
                            "Rs ${totalCredits.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),

                    // Total row if breakdown exists
                    if (creditsBreakdown.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(color: Colors.red),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Credits",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                          Text(
                            "Rs ${totalCredits.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

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

                  final date = DateFormat.yMMMd()
                      .format(DateTime.parse(d["date"]));
                  final status = d["status"] ?? "NOT_STARTED";
                  final salary = (d["salary"] ?? 0).toDouble();
                  final overtime = (d["overtimeHours"] ?? 0).toDouble();
                  final deduction = (d["deductionHours"] ?? 0).toDouble();
                  final overtimeReason = d["overtimeReason"];
                  final deductionReason = d["deductionReason"];
                  final hoursWorked = (d["hours"] ?? 0).toDouble();
                  final isQualified = d["qualified"] ?? false;

                  // Determine status display
                  bool isWorking = (status == "CHECKED_IN" || status == "COMPLETED");
                  bool hasStatus = (status != "NOT_STARTED");
                  Color statusColor = isWorking ? Colors.green : Colors.red;
                  IconData statusIcon = isWorking ? Icons.check_circle : Icons.cancel;
                  String statusText = isWorking ? "You are working today" : "You are not working today";

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: statusColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                                  // Only show status badge if user selected YES or NO
                                  if (hasStatus) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
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
                                            size: 14,
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
                                  // Show hours worked and qualification
                                  if (hoursWorked > 0 || status == "COMPLETED") ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${hoursWorked.toStringAsFixed(1)} hours worked",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        if (!isQualified && hoursWorked > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.orange.shade300,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              "Not qualified (need 6h)",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                  size: 16,
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
                                          fontSize: 12,
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
                                            fontSize: 11,
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
                                    fontSize: 13,
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
                                  size: 16,
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
                                          fontSize: 12,
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
                                            fontSize: 11,
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
                                    fontSize: 13,
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
            ),
          ],
        ),
      ),
    );
  }
}
