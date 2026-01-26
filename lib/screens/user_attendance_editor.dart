import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = "http://74.208.132.78/api";

class UserAttendanceEditorScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String token;

  const UserAttendanceEditorScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.token,
  });

  @override
  State<UserAttendanceEditorScreen> createState() =>
      _UserAttendanceEditorScreenState();
}

class _UserAttendanceEditorScreenState
    extends State<UserAttendanceEditorScreen> {
  bool loading = true;
  List<dynamic> attendanceList = [];
  int? selectedYear;
  int? selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse(
            "$apiBaseUrl/attendance/all?userId=${widget.userId}&year=$selectedYear&month=$selectedMonth"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          attendanceList = jsonDecode(res.body);
          loading = false;
        });
      } else {
        setState(() => loading = false);
        _showMessage("Failed to load attendance: ${res.body}");
      }
    } catch (e) {
      setState(() => loading = false);
      _showMessage("Error: $e");
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _editAttendanceRecord(Map<String, dynamic> record) async {
    final overtimeController = TextEditingController(
      text: (record["overtimeHours"] ?? 0).toString(),
    );
    final deductionController = TextEditingController(
      text: (record["deductionHours"] ?? 0).toString(),
    );
    final overtimeReasonController = TextEditingController(
      text: record["overtimeReason"] ?? '',
    );
    final deductionReasonController = TextEditingController(
      text: record["deductionReason"] ?? '',
    );

    // Status selection
    String selectedStatus = record["status"] ?? "NOT_WORKING";

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Attendance - ${_formatDate(record["workDate"])}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status selection
                const Text(
                  'Work Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('WORKING'),
                        value: 'WORKING',
                        groupValue: selectedStatus,
                        onChanged: (val) {
                          setDialogState(() => selectedStatus = val!);
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('NOT_WORKING'),
                        value: 'NOT_WORKING',
                        groupValue: selectedStatus,
                        onChanged: (val) {
                          setDialogState(() => selectedStatus = val!);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Overtime section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Overtime Hours',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: overtimeController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Hours (e.g., 2.5)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: overtimeReasonController,
                        decoration: InputDecoration(
                          hintText: 'Reason',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Deduction section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Deduction Hours',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: deductionController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Hours (e.g., 1.0)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: deductionReasonController,
                        decoration: InputDecoration(
                          hintText: 'Reason',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final overtime = double.tryParse(overtimeController.text) ?? 0;
      final deduction = double.tryParse(deductionController.text) ?? 0;

      await _saveAttendanceChanges(
        record["id"],
        selectedStatus,
        overtime,
        deduction,
        overtimeReasonController.text,
        deductionReasonController.text,
      );
    }
  }

  Future<void> _saveAttendanceChanges(
    int attendanceId,
    String status,
    double overtimeHours,
    double deductionHours,
    String overtimeReason,
    String deductionReason,
  ) async {
    try {
      final res = await http.put(
        Uri.parse("$apiBaseUrl/attendance/$attendanceId/admin-edit"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "status": status,
          "overtimeHours": overtimeHours,
          "deductionHours": deductionHours,
          "overtimeReason": overtimeReason,
          "deductionReason": deductionReason,
        }),
      );

      if (res.statusCode == 200) {
        _showMessage("Attendance updated successfully ✓");
        fetchAttendance(); // Reload data
      } else {
        _showMessage("Failed to update: ${res.body}");
      }
    } catch (e) {
      _showMessage("Error: $e");
    }
  }

  String _formatDate(String isoDate) {
    final d = DateTime.parse(isoDate).toLocal();
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year}";
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'WORKING':
        return Colors.green;
      case 'NOT_WORKING':
        return Colors.grey;
      case 'CHECKED_IN':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.userName}'s Attendance"),
        actions: [
          // Month selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Select Month',
            onSelected: (month) {
              setState(() => selectedMonth = month);
              fetchAttendance();
            },
            itemBuilder: (context) => List.generate(12, (index) {
              final month = index + 1;
              return PopupMenuItem(
                value: month,
                child: Text(
                  _getMonthName(month),
                  style: TextStyle(
                    fontWeight: selectedMonth == month
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
          // Year selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Year',
            onSelected: (year) {
              setState(() => selectedYear = year);
              fetchAttendance();
            },
            itemBuilder: (context) => List.generate(5, (index) {
              final year = DateTime.now().year - index;
              return PopupMenuItem(
                value: year,
                child: Text(
                  year.toString(),
                  style: TextStyle(
                    fontWeight: selectedYear == year
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : attendanceList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No attendance records for ${_getMonthName(selectedMonth!)} $selectedYear',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header info
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_getMonthName(selectedMonth!)} $selectedYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${attendanceList.length} records',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: attendanceList.length,
                        itemBuilder: (context, index) {
                          final record = attendanceList[index];
                          final status = record["status"] ?? "N/A";
                          final overtimeHours = record["overtimeHours"] ?? 0;
                          final deductionHours = record["deductionHours"] ?? 0;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _editAttendanceRecord(record),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDate(record["workDate"]),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Chip(
                                          label: Text(status),
                                          backgroundColor: _getStatusColor(status)
                                              .withOpacity(0.1),
                                          labelStyle: TextStyle(
                                            color: _getStatusColor(status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    if (overtimeHours > 0 ||
                                        deductionHours > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (overtimeHours > 0) ...[
                                            Icon(Icons.add_circle_outline,
                                                size: 16,
                                                color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'OT: ${overtimeHours}h',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          if (deductionHours > 0) ...[
                                            Icon(Icons.remove_circle_outline,
                                                size: 16,
                                                color: Colors.red.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Deduction: ${deductionHours}h',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    if (record["overtimeReason"] != null &&
                                        record["overtimeReason"].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'OT: ${record["overtimeReason"]}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    if (record["deductionReason"] != null &&
                                        record["deductionReason"].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Deduction: ${record["deductionReason"]}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Tap to edit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit,
                                            size: 14, color: Colors.blue.shade600),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}

