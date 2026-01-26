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
        final allUsers = List<Map<String, dynamic>>.from(jsonDecode(usersRes.body));
        // Filter to show only ADMIN users
        users = allUsers.where((user) => user['role'] == 'ADMIN').toList();
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
                  manual: att['manualCheckout'] == true,
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
    final overtimeReason = attendanceData['overtimeReason']?.toString() ?? '';
    final deductionReason = attendanceData['deductionReason']?.toString() ?? '';

    // Determine status text, color, and icon based on new system
    String displayStatus;
    Color statusColor;
    IconData statusIcon;

    if (status == 'WORKING') {
      displayStatus = 'WORKING';
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
    } else if (status == 'NOT_WORKING') {
      displayStatus = 'NOT WORKING';
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.cancel;
    } else if (status == 'COMPLETED') {
      // Legacy status from old system
      displayStatus = 'COMPLETED';
      statusColor = Colors.blue.shade700;
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'CHECKED_IN') {
      // Legacy status from old system
      displayStatus = 'CHECKED IN';
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.access_time;
    } else {
      displayStatus = 'NO RECORD';
      statusColor = Colors.red.shade700;
      statusIcon = Icons.error_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and Status Row
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      displayStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                tooltip: 'Edit attendance',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),

          // Overtime and Deduction Info
          if (overtimeHours > 0 || deductionHours > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (overtimeHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'OT: ${overtimeHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (deductionHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_circle_outline, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Deduct: ${deductionHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // Reasons
          if (overtimeReason.isNotEmpty || deductionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (overtimeReason.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'OT: $overtimeReason',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            if (deductionReason.isNotEmpty) ...[
              if (overtimeReason.isNotEmpty) const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Deduction: $deductionReason',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],

          // Legacy check-in/check-out times (only show if available)
          if (checkIn != null || checkOut != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${checkIn != null ? timeFmt.format(checkIn) : 'N/A'} - ${checkOut != null ? timeFmt.format(checkOut) : 'N/A'}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                if (minutesToShow != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${formatDuration(minutesToShow)})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
