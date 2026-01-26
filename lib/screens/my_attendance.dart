import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyAttendanceReportScreen extends StatefulWidget {
  const MyAttendanceReportScreen({super.key});

  @override
  State<MyAttendanceReportScreen> createState() =>
      _MyAttendanceReportScreenState();
}

class _MyAttendanceReportScreenState
    extends State<MyAttendanceReportScreen> {
  bool loading = true;
  String? token;
  List<dynamic> attendanceList = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");

    if (token == null) {
      Navigator.pushReplacementNamed(context, "/login");
      return;
    }

    await fetchAttendance();
    setState(() => loading = false);
  }

  Future<void> fetchAttendance() async {
    final res = await http.get(
      Uri.parse("http://74.208.132.78/api/attendance/history"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      attendanceList = jsonDecode(res.body);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load attendance")),
      );
    }
  }

  // 📅 Date formatter
  String formatDate(String isoDate) {
    final d = DateTime.parse(isoDate).toLocal();
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year}";
  }

  // ⏰ Time formatter
  String formatTime(String? iso) {
    if (iso == null) return "-";
    final utc = DateTime.parse(iso);
    final local = utc.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return "$hour:$minute $ampm";
  }

  // ⏱ Total hours formatter
  String formatTotalTime(int? totalMinutes) {
    if (totalMinutes == null || totalMinutes <= 0) return "--";
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  Map<String, dynamic> determineStatus(Map a) {
    // Check for new status-based system first
    final status = a["status"];

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (status == "WORKING") {
      statusText = "WORKED";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == "NOT_WORKING") {
      statusText = "DID NOT WORK";
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      // Fallback to old check-in/check-out system
      final checkIn = a["checkInTime"];
      final checkOut = a["checkOutTime"];

      if (checkIn != null && checkOut != null) {
        statusText = "COMPLETED";
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (checkIn != null && checkOut == null) {
        statusText = "Checked In";
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
      } else {
        statusText = "No Record";
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
      }
    }

    return {
      "text": statusText,
      "color": statusColor,
      "icon": statusIcon,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Attendance Report"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : attendanceList.isEmpty
          ? const Center(child: Text("No attendance records found"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: attendanceList.length,
        itemBuilder: (context, index) {
          final a = attendanceList[index];
          final statusInfo = determineStatus(a);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDate(a["workDate"]),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusInfo["color"].withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusInfo["color"],
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusInfo["icon"],
                              color: statusInfo["color"],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusInfo["text"],
                              style: TextStyle(
                                color: statusInfo["color"],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Overtime and Deduction Info
                  if (a["overtimeHours"] != null && a["overtimeHours"] > 0 ||
                      a["deductionHours"] != null && a["deductionHours"] > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (a["overtimeHours"] != null && a["overtimeHours"] > 0) ...[
                          Icon(Icons.add_circle_outline,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            "OT: ${a["overtimeHours"]}h",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (a["deductionHours"] != null && a["deductionHours"] > 0) ...[
                          Icon(Icons.remove_circle_outline,
                              size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            "Deduction: ${a["deductionHours"]}h",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Reasons (if available)
                  if (a["overtimeReason"] != null &&
                      a["overtimeReason"].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "OT: ${a["overtimeReason"]}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (a["deductionReason"] != null &&
                      a["deductionReason"].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Deduction: ${a["deductionReason"]}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Legacy check-in/check-out times (if available)
                  if (a["checkInTime"] != null || a["checkOutTime"] != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "${formatTime(a["checkInTime"])} - ${formatTime(a["checkOutTime"])}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (a["totalMinutes"] != null && a["totalMinutes"] > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            "(${formatTotalTime(a["totalMinutes"])})",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
