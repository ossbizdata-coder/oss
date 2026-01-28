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
    try {
      print("DEBUG: Fetching attendance history...");

      // Try the /history endpoint first
      var res = await http.get(
        Uri.parse("http://74.208.132.78/api/attendance/history"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("DEBUG: Attendance response status: ${res.statusCode}");

      // If 403, the endpoint might not exist - show helpful message
      if (res.statusCode == 403) {
        print("DEBUG: 403 Forbidden - endpoint blocked or doesn't exist");
        print("DEBUG: This usually means the backend endpoint needs to be implemented");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Attendance history endpoint not available. Please contact administrator."),
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() => attendanceList = []);
        return;
      }

      print("DEBUG: Attendance response body: ${res.body}");

      if (res.statusCode == 200) {
        if (res.body.isEmpty || res.body == 'null') {
          print("DEBUG: Empty response body");
          setState(() => attendanceList = []);
          return;
        }

        final decoded = jsonDecode(res.body);
        print("DEBUG: Decoded data type: ${decoded.runtimeType}");

        // Debug: Print first record structure if available
        if (decoded is List && decoded.isNotEmpty) {
          print("DEBUG: First record structure: ${decoded[0]}");
          print("DEBUG: First record keys: ${(decoded[0] as Map).keys.toList()}");
          print("DEBUG: overtimeHours value: ${decoded[0]['overtimeHours']}, type: ${decoded[0]['overtimeHours'].runtimeType}");
          print("DEBUG: deductionHours value: ${decoded[0]['deductionHours']}, type: ${decoded[0]['deductionHours'].runtimeType}");
        } else if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List && data.isNotEmpty) {
            print("DEBUG: First record structure: ${data[0]}");
            print("DEBUG: First record keys: ${(data[0] as Map).keys.toList()}");
            print("DEBUG: overtimeHours value: ${data[0]['overtimeHours']}, type: ${data[0]['overtimeHours'].runtimeType}");
            print("DEBUG: deductionHours value: ${data[0]['deductionHours']}, type: ${data[0]['deductionHours'].runtimeType}");
          }
        }

        // Get today's date as timestamp (end of day)
        final today = DateTime.now();
        final todayEndOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
        final todayTimestamp = todayEndOfDay.millisecondsSinceEpoch;

        if (decoded is List) {
          // Filter records up to today only, then sort by workDate in descending order
          final filtered = List<dynamic>.from(decoded).where((record) {
            final workDate = record['workDate'];
            if (workDate == null) return false;

            // Handle both timestamp and ISO date string
            int recordTimestamp;
            if (workDate is int) {
              recordTimestamp = workDate;
            } else if (workDate is String) {
              try {
                // Try parsing as ISO date
                recordTimestamp = DateTime.parse(workDate).millisecondsSinceEpoch;
              } catch (e) {
                // Try parsing as timestamp string
                try {
                  recordTimestamp = int.parse(workDate);
                } catch (e2) {
                  return false;
                }
              }
            } else {
              return false;
            }

            // Only include if workDate <= today
            return recordTimestamp <= todayTimestamp;
          }).toList();

          filtered.sort((a, b) {
            // Sort by workDate in descending order
            final dateA = a['workDate'];
            final dateB = b['workDate'];

            // Handle comparison for both int and string
            if (dateA is int && dateB is int) {
              return dateB.compareTo(dateA);
            } else if (dateA is String && dateB is String) {
              return dateB.compareTo(dateA);
            } else {
              // Mixed types, convert to comparable format
              return 0;
            }
          });
          setState(() => attendanceList = filtered);
          print("DEBUG: Loaded ${attendanceList.length} attendance records up to today (sorted DESC)");
        } else if (decoded is Map && decoded.containsKey('data')) {
          // Filter records up to today only, then sort by workDate in descending order
          final filtered = List<dynamic>.from(decoded['data'] ?? []).where((record) {
            final workDate = record['workDate'];
            if (workDate == null) return false;

            // Handle both timestamp and ISO date string
            int recordTimestamp;
            if (workDate is int) {
              recordTimestamp = workDate;
            } else if (workDate is String) {
              try {
                // Try parsing as ISO date
                recordTimestamp = DateTime.parse(workDate).millisecondsSinceEpoch;
              } catch (e) {
                // Try parsing as timestamp string
                try {
                  recordTimestamp = int.parse(workDate);
                } catch (e2) {
                  return false;
                }
              }
            } else {
              return false;
            }

            // Only include if workDate <= today
            return recordTimestamp <= todayTimestamp;
          }).toList();

          filtered.sort((a, b) {
            // Sort by workDate in descending order
            final dateA = a['workDate'];
            final dateB = b['workDate'];

            // Handle comparison for both int and string
            if (dateA is int && dateB is int) {
              return dateB.compareTo(dateA);
            } else if (dateA is String && dateB is String) {
              return dateB.compareTo(dateA);
            } else {
              // Mixed types, convert to comparable format
              return 0;
            }
          });
          setState(() => attendanceList = filtered);
          print("DEBUG: Loaded ${attendanceList.length} attendance records from 'data' field up to today (sorted DESC)");
        } else {
          print("DEBUG: Unexpected response format: $decoded");
          setState(() => attendanceList = []);
        }
      } else {
        print("DEBUG: Failed with status ${res.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load attendance: ${res.statusCode}")),
          );
        }
      }
    } catch (e) {
      print("DEBUG: Error fetching attendance: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading attendance: $e")),
        );
      }
    }
  }

  // 📅 Date formatter - handles both ISO date strings and timestamps
  String formatDate(dynamic dateValue) {
    DateTime d;

    if (dateValue is int) {
      // Handle timestamp in milliseconds
      d = DateTime.fromMillisecondsSinceEpoch(dateValue).toLocal();
    } else if (dateValue is String) {
      // Try parsing as ISO date string first
      try {
        d = DateTime.parse(dateValue).toLocal();
      } catch (e) {
        // If parsing fails, try as timestamp string
        try {
          d = DateTime.fromMillisecondsSinceEpoch(int.parse(dateValue)).toLocal();
        } catch (e2) {
          print("DEBUG: Failed to parse date: $dateValue");
          return dateValue.toString();
        }
      }
    } else {
      return dateValue.toString();
    }

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
    // Check the status field from database
    final status = a["status"];
    final checkIn = a["checkInTime"];

    String statusText;
    Color statusColor;
    IconData statusIcon;

    // Check status field first (for records from database)
    if (status == "WORKING" || status == "CHECKED_IN") {
      statusText = "WORKED";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == "NOT_WORKING") {
      statusText = "DID NOT WORK";
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (checkIn != null) {
      // Fallback: If they checked in at all, they worked
      statusText = "WORKED";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusText = "DID NOT WORK";
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
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
          : RefreshIndicator(
              onRefresh: () async {
                await fetchAttendance();
              },
              child: attendanceList.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No attendance records found",
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Pull down to refresh",
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDate(a["workDate"]),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Show overtime and deduction hours under the date
                          Builder(
                            builder: (context) {
                              // Safely parse overtime and deduction hours
                              final overtimeHours = a["overtimeHours"];
                              final deductionHours = a["deductionHours"];

                              // Convert to double for comparison
                              double? overtimeValue;
                              double? deductionValue;

                              if (overtimeHours != null) {
                                if (overtimeHours is num) {
                                  overtimeValue = overtimeHours.toDouble();
                                } else if (overtimeHours is String) {
                                  overtimeValue = double.tryParse(overtimeHours);
                                }
                              }

                              if (deductionHours != null) {
                                if (deductionHours is num) {
                                  deductionValue = deductionHours.toDouble();
                                } else if (deductionHours is String) {
                                  deductionValue = double.tryParse(deductionHours);
                                }
                              }

                              print("DEBUG: Record ${a["workDate"]} - OT: $overtimeValue, Deduction: $deductionValue");

                              final hasOvertime = overtimeValue != null && overtimeValue > 0;
                              final hasDeduction = deductionValue != null && deductionValue > 0;

                              if (!hasOvertime && !hasDeduction) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (hasOvertime) ...[
                                        Icon(Icons.add_circle_outline,
                                            size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${overtimeValue!.toStringAsFixed(1)}h OT",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (hasDeduction) const SizedBox(width: 12),
                                      ],
                                      if (hasDeduction) ...[
                                        Icon(Icons.remove_circle_outline,
                                            size: 14, color: Colors.red.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${deductionValue!.toStringAsFixed(1)}h Off",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
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
                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }
}
