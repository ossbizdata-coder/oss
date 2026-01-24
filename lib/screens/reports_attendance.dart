import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/attendance_adjustment_dialog.dart';

class ReportsAttendanceScreen extends StatefulWidget {
  const ReportsAttendanceScreen({super.key});

  @override
  State<ReportsAttendanceScreen> createState() =>
      _ReportsAttendanceScreenState();
}

class _ReportsAttendanceScreenState extends State<ReportsAttendanceScreen> {
  List users = [];
  Map<int, List> userAttendance = {};
  bool loading = true;
  String? error;

  final dateFmt = DateFormat('dd MMM yyyy');
  final timeFmt = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    fetchAttendanceForAllUsers();
  }

  /// 🔹 Convert minutes → "Xh Ym"
  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> fetchAttendanceForAllUsers() async {
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

      // ------------------ USERS ------------------
      final usersRes = await http.get(
        Uri.parse('http://74.208.132.78/api/users'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (usersRes.statusCode != 200) {
        setState(() {
          error = "Failed to load users (Status: ${usersRes.statusCode})";
          loading = false;
        });
        return;
      }

      try {
        users = List<Map<String, dynamic>>.from(jsonDecode(usersRes.body));
      } catch (e) {
        setState(() {
          error = "Failed to parse users data: $e";
          loading = false;
        });
        return;
      }

      // ---------------- ATTENDANCE ----------------
      final attRes = await http.get(
        Uri.parse('http://74.208.132.78/api/attendance/all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (attRes.statusCode != 200) {
        setState(() {
          error = "Failed to load attendance (Status: ${attRes.statusCode})";
          loading = false;
        });
        return;
      }

      final List allAttendance;
      try {
        allAttendance = jsonDecode(attRes.body);
      } catch (e) {
        setState(() {
          error = "Failed to parse attendance data: $e";
          loading = false;
        });
        return;
      }

      // ---------------- MAPPING ----------------
      userAttendance.clear();
      for (var att in allAttendance) {
        final userId = int.tryParse(
          att['userId']?.toString() ?? att['user']?['id']?.toString() ?? '',
        );
        if (userId == null) continue;

        userAttendance.putIfAbsent(userId, () => []).add(att);
      }

      // ---------------- SORT DESC ----------------
      userAttendance.forEach((key, list) {
        list.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['workDate'] ?? '') ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b['workDate'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA); // Descending
        });
      });

      setState(() => loading = false);
    } catch (e, st) {
      // debugPrint('Error fetching attendance: $e\n$st');
      setState(() {
        error = "Error: $e";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
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
            onPressed: loading ? null : fetchAttendanceForAllUsers,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : users.isEmpty
          ? const Center(child: Text('No users found'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          // Add null safety for userId
          final userId = user['id'] is int
              ? user['id']
              : int.tryParse(user['id']?.toString() ?? '');

          if (userId == null) {
            // Skip users with invalid IDs
            return const SizedBox.shrink();
          }

          final attList = userAttendance[userId] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(
                user['name'] ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                user['email'] ?? '',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: Color.fromARGB(
                    (0.15 * 255).toInt(),
                    primary.red,
                    primary.green,
                    primary.blue),
                child: Icon(Icons.person, color: primary),
              ),
              children: attList.isEmpty
                  ? const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child:
                  Text('No attendance records found'),
                )
              ]
                  : attList.map<Widget>((att) {
                DateTime? workDate, checkIn, checkOut;
                int? totalMinutes;
                String? status;

                try {
                  if (att['workDate'] != null) {
                    workDate = DateTime.parse(
                        att['workDate'])
                        .toUtc()
                        .toLocal();
                  }
                  if (att['checkInTime'] != null) {
                    checkIn = DateTime.parse(
                        att['checkInTime'])
                        .toUtc()
                        .toLocal();
                  }
                  if (att['checkOutTime'] != null) {
                    checkOut = DateTime.parse(
                        att['checkOutTime'])
                        .toUtc()
                        .toLocal();
                  }
                  if (att['totalMinutes'] != null) {
                    totalMinutes =
                    att['totalMinutes'] is int
                        ? att['totalMinutes']
                        : int.tryParse(att[
                    'totalMinutes']
                        .toString());
                  }
                  status = att['status']?.toString();
                } catch (_) {}

                return _attendanceRow(
                  primary: primary,
                  date: workDate,
                  checkIn: checkIn,
                  checkOut: checkOut,
                  totalMinutes: totalMinutes,
                  status: status,
                  manual: att['manual'] == true,
                  attendanceData: att,
                  userName: user['name'] ?? 'N/A',
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _attendanceRow({
    required Color primary,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
    int? totalMinutes,
    String? status,
    bool manual = false,
    required Map<String, dynamic> attendanceData,
    required String userName,
  }) {
    final computedMinutes =
    (checkIn != null && checkOut != null) ? checkOut.difference(checkIn).inMinutes : null;

    final minutesToShow = totalMinutes ?? computedMinutes;

    final overtimeHours = (attendanceData['overtimeHours'] ?? 0).toDouble();
    final deductionHours = (attendanceData['deductionHours'] ?? 0).toDouble();

    // Determine status text & color
    String displayStatus;
    Color statusColor;

    if (manual) {
      displayStatus = 'MANUAL';
      statusColor = Colors.orange.shade800;
    } else if (status != null && status == 'COMPLETED') {
      displayStatus = 'COMPLETED';
      statusColor = Colors.green.shade800;
    } else {
      displayStatus = 'PENDING';
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null ? dateFmt.format(date) : 'Unknown date',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${checkIn != null ? timeFmt.format(checkIn) : 'N/A'}'
                          ' • ${checkOut != null ? timeFmt.format(checkOut) : 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    if (minutesToShow != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${formatDuration(minutesToShow)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    Text(
                      displayStatus,
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AttendanceAdjustmentDialog(
                      attendance: {
                        ...attendanceData,
                        'userName': userName,
                      },
                      onSuccess: fetchAttendanceForAllUsers,
                    ),
                  );
                },
                tooltip: 'Add overtime/deduction',
              ),
            ],
          ),

          // Show overtime/deduction badges
          if (overtimeHours > 0 || deductionHours > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (overtimeHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'OT: ${overtimeHours.toStringAsFixed(1)}h',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                if (overtimeHours > 0 && deductionHours > 0)
                  const SizedBox(width: 8),
                if (deductionHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_circle_outline, size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Deduct: ${deductionHours.toStringAsFixed(1)}h',
                          style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
