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
    final checkIn = a["checkInTime"];
    final checkOut = a["checkOutTime"];
    final manualCheckout = a["manualCheckout"] == true;

    String statusText;
    Color statusColor;

    if (checkIn != null && checkOut != null) {
      statusText = "COMPLETED";
      statusColor = Colors.green;
    } else if (checkIn != null && checkOut == null) {
      statusText = "Checked In";
      statusColor = Colors.orange;
    } else {
      statusText = "Pending";
      statusColor = Colors.red;
    }

    return {
      "text": statusText,
      "color": statusColor,
      "manualCheckout": manualCheckout
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
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            formatDate(a["workDate"]),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "(${formatTotalTime(a["totalMinutes"])} )",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: (a["totalMinutes"] == null ||
                                  a["totalMinutes"] <= 0)
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Chip(
                        label: Text(statusInfo["text"]),
                        backgroundColor: statusInfo["color"]
                            .withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: statusInfo["color"],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${formatTime(a["checkInTime"])} - ${formatTime(a["checkOutTime"])}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
