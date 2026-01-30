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

        // Get today's date as timestamp (start of day for comparison)
        final today = DateTime.now();
        final todayStartOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
        final todayTimestamp = todayStartOfDay.millisecondsSinceEpoch;

        if (decoded is List) {
          // Filter records up to today only (exclude future dates)
          final filtered = List<dynamic>.from(decoded).where((record) {
            final workDate = record['workDate'];
            if (workDate == null) return false;

            // Parse workDate to DateTime
            DateTime recordDate;
            if (workDate is int) {
              recordDate = DateTime.fromMillisecondsSinceEpoch(workDate);
            } else if (workDate is String) {
              try {
                recordDate = DateTime.parse(workDate);
              } catch (e) {
                try {
                  recordDate = DateTime.fromMillisecondsSinceEpoch(int.parse(workDate));
                } catch (e2) {
                  return false;
                }
              }
            } else {
              return false;
            }

            // Only include if date is today or in the past (exclude future dates)
            final recordDateOnly = DateTime(recordDate.year, recordDate.month, recordDate.day);
            final todayDateOnly = DateTime(today.year, today.month, today.day);
            return !recordDateOnly.isAfter(todayDateOnly);
          }).toList();

          // Deduplicate: Group by date (ignoring time) and keep the most recent record per date
          final Map<String, dynamic> uniqueRecords = {};
          for (var record in filtered) {
            final workDate = record['workDate'];
            DateTime dateTime;

            if (workDate is int) {
              dateTime = DateTime.fromMillisecondsSinceEpoch(workDate);
            } else if (workDate is String) {
              try {
                dateTime = DateTime.parse(workDate);
              } catch (e) {
                try {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(workDate));
                } catch (e2) {
                  continue;
                }
              }
            } else {
              continue;
            }

            // Create date key (YYYY-MM-DD)
            final dateKey = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

            // ✅ FIX: Always REPLACE to keep last occurrence (most recent from backend)
            // The /history endpoint doesn't return 'id' field, so we can't compare IDs
            // Backend returns older records first, so last occurrence = most recent action
            uniqueRecords[dateKey] = record;
            print("DEBUG: Date $dateKey - Updating with status=${record['status']}");
          }

          // Convert back to list and sort by workDate in descending order
          final deduplicated = uniqueRecords.values.toList();
          deduplicated.sort((a, b) {
            final timestampA = _getTimestamp(a['workDate']);
            final timestampB = _getTimestamp(b['workDate']);
            return timestampB.compareTo(timestampA);
          });

          setState(() => attendanceList = deduplicated);

          // Debug: Show all unique dates we have records for
          print("DEBUG: Loaded ${attendanceList.length} unique attendance records up to today (sorted DESC)");
          print("DEBUG: Dates with records:");
          for (var record in deduplicated.take(5)) {
            final workDate = record['workDate'];
            final dateTime = workDate is int
                ? DateTime.fromMillisecondsSinceEpoch(workDate)
                : DateTime.parse(workDate.toString());
            final dateStr = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
            final status = record['status'];
            final isWorking = record['isWorking'];
            print("DEBUG:   $dateStr - status=$status, isWorking=$isWorking");
          }

          // Check if we have a record for today
          final todayDateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
          final hasToday = deduplicated.any((r) {
            final workDate = r['workDate'];
            final dateTime = workDate is int
                ? DateTime.fromMillisecondsSinceEpoch(workDate)
                : DateTime.parse(workDate.toString());
            final dateStr = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
            return dateStr == todayDateStr;
          });
          print("DEBUG: Has record for TODAY ($todayDateStr)? $hasToday");
        } else if (decoded is Map && decoded.containsKey('data')) {
          // Filter records up to today only
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

          // Deduplicate: Group by date (ignoring time) and keep the most recent record per date
          final Map<String, dynamic> uniqueRecords = {};
          for (var record in filtered) {
            final workDate = record['workDate'];
            DateTime dateTime;

            if (workDate is int) {
              dateTime = DateTime.fromMillisecondsSinceEpoch(workDate);
            } else if (workDate is String) {
              try {
                dateTime = DateTime.parse(workDate);
              } catch (e) {
                try {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(workDate));
                } catch (e2) {
                  continue;
                }
              }
            } else {
              continue;
            }

            // Create date key (YYYY-MM-DD)
            final dateKey = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

            // ✅ FIX: Always REPLACE to keep last occurrence (most recent from backend)
            // The /history endpoint doesn't return 'id' field, so we can't compare IDs
            // Backend returns older records first, so last occurrence = most recent action
            uniqueRecords[dateKey] = record;
            print("DEBUG: Date $dateKey - Updating with status=${record['status']}");
          }

          // Convert back to list and sort by workDate in descending order
          final deduplicated = uniqueRecords.values.toList();
          deduplicated.sort((a, b) {
            final timestampA = _getTimestamp(a['workDate']);
            final timestampB = _getTimestamp(b['workDate']);
            return timestampB.compareTo(timestampA);
          });

          setState(() => attendanceList = deduplicated);
          print("DEBUG: Loaded ${attendanceList.length} unique attendance records from 'data' field up to today (sorted DESC)");
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

  // Helper method to get timestamp from workDate (handles both int and string)
  int _getTimestamp(dynamic workDate) {
    if (workDate is int) {
      return workDate;
    } else if (workDate is String) {
      try {
        return DateTime.parse(workDate).millisecondsSinceEpoch;
      } catch (e) {
        try {
          return int.parse(workDate);
        } catch (e2) {
          return 0;
        }
      }
    }
    return 0;
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

  Map<String, dynamic> determineStatus(Map a) {
    // ✅ NEW SIMPLIFIED LOGIC: Check is_working flag first (if available)
    // Backend now uses is_working boolean flag (true = worked, false = didn't work)

    final isWorking = a["isWorking"];
    String statusText;
    Color statusColor;
    IconData statusIcon;

    // Priority 1: Check is_working flag (new simplified backend)
    if (isWorking != null) {
      if (isWorking == true || isWorking == 1) {
        statusText = "WORKED";
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else {
        statusText = "DID NOT WORK";
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
      }
    }
    // Priority 2: Fallback to old status field for backward compatibility
    else {
      final status = a["status"];

      if (status == "NOT_WORKING") {
        statusText = "DID NOT WORK";
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
      } else {
        // WORKING, CHECKED_IN, COMPLETED all mean user selected YES (worked)
        statusText = "WORKED";
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
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
    // Check if we have a record for today
    final today = DateTime.now();
    final todayDateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final hasToday = attendanceList.any((r) {
      final workDate = r['workDate'];
      final dateTime = workDate is int
          ? DateTime.fromMillisecondsSinceEpoch(workDate)
          : DateTime.parse(workDate.toString());
      final dateStr = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
      return dateStr == todayDateStr;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Attendance Report"),
      ),
      // ✅ ADD: Floating button to create today's record if missing
      floatingActionButton: !loading && !hasToday ? FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to attendance screen to mark today
          await Navigator.pushNamed(context, '/attendance');
          // Reload after coming back
          await fetchAttendance();
        },
        icon: const Icon(Icons.add),
        label: const Text("Mark Today"),
        backgroundColor: Colors.blue,
      ) : null,
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
                                  if (hasOvertime) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_circle_outline,
                                            size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${overtimeValue.toStringAsFixed(1)}h OT${a["overtimeReason"] != null && a["overtimeReason"].toString().isNotEmpty ? ' (${a["overtimeReason"]})' : ''}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    if (hasDeduction) const SizedBox(height: 4),
                                  ],
                                  if (hasDeduction) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.remove_circle_outline,
                                            size: 14, color: Colors.red.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${deductionValue.toStringAsFixed(1)}h Off${a["deductionReason"] != null && a["deductionReason"].toString().isNotEmpty ? ' (${a["deductionReason"]})' : ''}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
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
