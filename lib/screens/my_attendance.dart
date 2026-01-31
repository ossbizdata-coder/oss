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
      var res = await http.get(
        Uri.parse("http://74.208.132.78/api/attendance/history"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (res.statusCode == 403) {
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

      if (res.statusCode == 200) {
        if (res.body.isEmpty || res.body == 'null') {
          setState(() => attendanceList = []);
          return;
        }

        final decoded = jsonDecode(res.body);

        final today = DateTime.now();
        final todayStartOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
        final todayTimestamp = todayStartOfDay.millisecondsSinceEpoch;

        if (decoded is List) {
          final filtered = decoded.where((record) {
            final workDate = record['workDate'];
            if (workDate == null) return false;

            DateTime recordDate;
            if (workDate is int) {
              recordDate = DateTime.fromMillisecondsSinceEpoch(workDate, isUtc: true);
            } else if (workDate is String) {
              try {
                if (workDate.contains('-') && workDate.length == 10 && !workDate.contains('T')) {
                  final parts = workDate.split('-');
                  recordDate = DateTime.utc(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                    int.parse(parts[2]),
                  );
                } else {
                  recordDate = DateTime.parse(workDate).toUtc();
                }
              } catch (e) {
                try {
                  recordDate = DateTime.fromMillisecondsSinceEpoch(int.parse(workDate), isUtc: true);
                } catch (e2) {
                  return false;
                }
              }
            } else {
              return false;
            }

            return recordDate.millisecondsSinceEpoch <= todayTimestamp;
          }).toList();

          final Map<String, dynamic> uniqueRecords = {};
          for (var record in filtered) {
            final workDate = record['workDate'];
            DateTime dateTime;

            if (workDate is int) {
              dateTime = DateTime.fromMillisecondsSinceEpoch(workDate, isUtc: true);
            } else if (workDate is String) {
              try {
                if (workDate.contains('-') && workDate.length == 10 && !workDate.contains('T')) {
                  final parts = workDate.split('-');
                  dateTime = DateTime.utc(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                    int.parse(parts[2]),
                  );
                } else {
                  dateTime = DateTime.parse(workDate).toUtc();
                }
              } catch (e) {
                try {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(workDate), isUtc: true);
                } catch (e2) {
                  continue;
                }
              }
            } else {
              continue;
            }

            final dateKey = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

            uniqueRecords[dateKey] = record;
          }

          final deduplicated = uniqueRecords.values.toList();
          deduplicated.sort((a, b) {
            final timestampA = _getTimestamp(a['workDate']);
            final timestampB = _getTimestamp(b['workDate']);
            return timestampB.compareTo(timestampA);
          });

          setState(() => attendanceList = deduplicated);
        } else if (decoded is Map && decoded.containsKey('data')) {
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

          final Map<String, dynamic> uniqueRecords = {};
          for (var record in filtered) {
            final workDate = record['workDate'];
            DateTime dateTime;

            if (workDate is int) {
              dateTime = DateTime.fromMillisecondsSinceEpoch(workDate, isUtc: true);
            } else if (workDate is String) {
              try {
                if (workDate.contains('T')) {
                  dateTime = DateTime.parse(workDate).toUtc();
                } else if (workDate.contains('-') && workDate.length == 10) {
                  final parts = workDate.split('-');
                  if (parts.length == 3) {
                    dateTime = DateTime.utc(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                      int.parse(parts[2]),
                    );
                  } else {
                    throw FormatException('Invalid date format');
                  }
                } else {
                  dateTime = DateTime.parse(workDate).toUtc();
                }
              } catch (e) {
                try {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(workDate), isUtc: true);
                } catch (e2) {
                  continue;
                }
              }
            } else {
              continue;
            }

            final dateKey = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

            uniqueRecords[dateKey] = record;
          }

          final deduplicated = uniqueRecords.values.toList();
          deduplicated.sort((a, b) {
            final timestampA = _getTimestamp(a['workDate']);
            final timestampB = _getTimestamp(b['workDate']);
            return timestampB.compareTo(timestampA);
          });

          setState(() => attendanceList = deduplicated);
        } else {
          setState(() => attendanceList = []);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load attendance: ${res.statusCode}")),
          );
        }
      }
    } catch (e) {
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
        return DateTime.parse(workDate).toUtc().millisecondsSinceEpoch;
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

  String formatDate(dynamic dateValue) {
    DateTime d;

    if (dateValue is int) {
      d = DateTime.fromMillisecondsSinceEpoch(dateValue, isUtc: true);
    } else if (dateValue is String) {
      try {
        if (dateValue.contains('T')) {
          d = DateTime.parse(dateValue).toUtc();
        } else if (dateValue.contains('-') && dateValue.length == 10) {
          final parts = dateValue.split('-');
          if (parts.length == 3) {
            d = DateTime.utc(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            throw FormatException('Invalid date format');
          }
        } else {
          d = DateTime.parse(dateValue).toUtc();
        }
      } catch (e) {
        try {
          d = DateTime.fromMillisecondsSinceEpoch(int.parse(dateValue), isUtc: true);
        } catch (e2) {
          return dateValue.toString();
        }
      }
    } else {
      return 'N/A';
    }

    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year}";
  }

  Map<String, dynamic> determineStatus(Map a) {
    final isWorking = a["isWorking"];
    String statusText;
    Color statusColor;
    IconData statusIcon;

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
    else {
      final status = a["status"];

      if (status == "NOT_WORKING") {
        statusText = "DID NOT WORK";
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
      } else {
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
    final today = DateTime.now();
    final todayDateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final hasToday = attendanceList.any((r) {
      final workDate = r['workDate'];
      DateTime dateTime;
      if (workDate is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(workDate, isUtc: true);
      } else {
        dateTime = DateTime.parse(workDate.toString()).toUtc();
      }
      final dateStr = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
      return dateStr == todayDateStr;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Attendance Report"),
      ),
      floatingActionButton: !loading && !hasToday ? FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/attendance');
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
