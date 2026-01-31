import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceAdjustmentDialog extends StatefulWidget {
  final Map<String, dynamic> attendance;
  final VoidCallback onSuccess;

  const AttendanceAdjustmentDialog({
    super.key,
    required this.attendance,
    required this.onSuccess,
  });

  @override
  State<AttendanceAdjustmentDialog> createState() =>
      _AttendanceAdjustmentDialogState();
}

class _AttendanceAdjustmentDialogState
    extends State<AttendanceAdjustmentDialog> {
  final _overtimeController = TextEditingController();
  final _deductionController = TextEditingController();
  final _overtimeReasonController = TextEditingController();
  final _deductionReasonController = TextEditingController();
  bool _saving = false;
  String _selectedStatus = 'WORKING'; // Default to WORKING

  @override
  void initState() {
    super.initState();
    // Pre-fill if values exist
    final overtime = widget.attendance['overtimeHours'] ?? 0;
    final deduction = widget.attendance['deductionHours'] ?? 0;
    final currentStatus = widget.attendance['status'] ?? 'WORKING';

    _selectedStatus = currentStatus;
    _overtimeController.text = overtime > 0 ? overtime.toString() : '';
    _deductionController.text = deduction > 0 ? deduction.toString() : '';
    _overtimeReasonController.text = widget.attendance['overtimeReason'] ?? '';
    _deductionReasonController.text = widget.attendance['deductionReason'] ?? '';
  }

  @override
  void dispose() {
    _overtimeController.dispose();
    _deductionController.dispose();
    _overtimeReasonController.dispose();
    _deductionReasonController.dispose();
    super.dispose();
  }

  Future<void> _saveAdjustments() async {
    final overtime = double.tryParse(_overtimeController.text) ?? 0;
    final deduction = double.tryParse(_deductionController.text) ?? 0;

    print('═══════════════════════════════════════════════════════');
    print('📝 ATTENDANCE ADJUSTMENT - Starting Save Process');
    print('═══════════════════════════════════════════════════════');

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final role = prefs.getString("role");
      final userId = prefs.getInt("userId");
      final attendanceId = widget.attendance['id'];

      print('🔐 Auth Details:');
      print('   - User ID: $userId');
      print('   - Role: $role');
      print('   - Token exists: ${token != null}');
      print('   - Token length: ${token?.length ?? 0}');
      if (token != null && token.length > 20) {
        print('   - Token preview: ${token.substring(0, 20)}...');
      }

      print('📊 Attendance Record:');
      print('   - User Name: ${widget.attendance['userName']}');
      print('   - Work Date: ${widget.attendance['workDate']}');
      print('   - User ID: ${widget.attendance['userId']}');
      print('   - Current Status: ${widget.attendance['status']}');
      print('   - New Status: $_selectedStatus');

      print('⏱️ Adjustment Values:');
      print('   - Overtime Hours: $overtime');
      print('   - Overtime Reason: ${_overtimeReasonController.text.trim()}');
      print('   - Deduction Hours: $deduction');
      print('   - Deduction Reason: ${_deductionReasonController.text.trim()}');


      // Get userId and workDate for composite key approach
      final targetUserId = widget.attendance['userId'];
      final workDate = widget.attendance['workDate'];

      print('🔑 Using Composite Key Approach:');
      print('   - User ID: $targetUserId');
      print('   - Work Date: $workDate');

      if (targetUserId == null || workDate == null) {
        print('❌ ERROR: Missing userId or workDate for composite key!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Missing user ID or work date'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _saving = false);
        return;
      }

      final currentStatus = widget.attendance['status'] ?? 'WORKING';
      if (_selectedStatus != currentStatus) {
        print('───────────────────────────────────────────────────────');
        print('🔄 STATUS UPDATE REQUIRED');
        print('   - From: $currentStatus → To: $_selectedStatus');

        // Use composite key endpoint: userId and date in query params or body
        final statusUrl = 'http://74.208.132.78/api/attendance/update-status';
        final statusBody = jsonEncode({
          'userId': targetUserId,
          'workDate': workDate,
          'status': _selectedStatus,
        });

        print('📤 API Request - Update Status:');
        print('   - URL: $statusUrl');
        print('   - Method: PUT');
        print('   - Headers: Content-Type: application/json, Authorization: Bearer {token}');
        print('   - Body: $statusBody');

        final statusResponse = await http.put(
          Uri.parse(statusUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: statusBody,
        );

        print('📥 API Response - Update Status:');
        print('   - Status Code: ${statusResponse.statusCode}');
        print('   - Response Body: ${statusResponse.body}');
        print('   - Headers: ${statusResponse.headers}');

        if (statusResponse.statusCode != 200) {
          print('❌ Status update FAILED!');
          print('   - Expected: 200, Got: ${statusResponse.statusCode}');
          print('   - Error Response: ${statusResponse.body}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update status: ${statusResponse.statusCode} - ${statusResponse.body}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 7),
              ),
            );
          }
          setState(() => _saving = false);
          return;
        }
        print('✅ Status update SUCCESS');
      } else {
        print('ℹ️ Status unchanged - skipping status update');
      }

      print('───────────────────────────────────────────────────────');
      print('🔄 ADJUSTMENTS UPDATE');

      // Use composite key endpoint
      final adjustmentsUrl = 'http://74.208.132.78/api/attendance/update-adjustments';
      final adjustmentsBody = jsonEncode({
        'userId': targetUserId,
        'workDate': workDate,
        'overtimeHours': overtime,
        'deductionHours': deduction,
        'overtimeReason': _overtimeReasonController.text.trim(),
        'deductionReason': _deductionReasonController.text.trim(),
      });

      print('📤 API Request - Update Adjustments:');
      print('   - URL: $adjustmentsUrl');
      print('   - Method: PUT');
      print('   - Headers: Content-Type: application/json, Authorization: Bearer {token}');
      print('   - Body: $adjustmentsBody');

      final response = await http.put(
        Uri.parse(adjustmentsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: adjustmentsBody,
      );

      print('📥 API Response - Update Adjustments:');
      print('   - Status Code: ${response.statusCode}');
      print('   - Response Body: ${response.body}');
      print('   - Headers: ${response.headers}');

      if (response.statusCode == 200) {
        print('✅ Adjustments update SUCCESS');
        print('═══════════════════════════════════════════════════════');
        print('✨ ATTENDANCE ADJUSTMENT COMPLETED SUCCESSFULLY');
        print('═══════════════════════════════════════════════════════');

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Changes saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
        }
      } else {
        print('❌ Adjustments update FAILED!');
        print('   - Expected: 200, Got: ${response.statusCode}');
        print('   - Error Response: ${response.body}');
        print('═══════════════════════════════════════════════════════');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 7),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION CAUGHT!');
      print('   - Error Type: ${e.runtimeType}');
      print('   - Error Message: $e');
      print('   - Stack Trace:');
      print(stackTrace);
      print('═══════════════════════════════════════════════════════');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workDate = widget.attendance['workDate'];
    final userName = widget.attendance['userName'] ?? 'Unknown';
    final status = widget.attendance['status'] ?? 'UNKNOWN';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Adjustment',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      workDate != null
                          ? (() {
                              try {
                                final date = workDate is int
                                    ? DateTime.fromMillisecondsSinceEpoch(workDate, isUtc: true)
                                    : DateTime.parse(workDate.toString()).toUtc();
                                return DateFormat.yMMMd().format(date);
                              } catch (e) {
                                return workDate.toString();
                              }
                            })()
                          : 'Unknown date',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // YES/NO STATUS TOGGLE
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Attendance Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _selectedStatus = 'WORKING';
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedStatus == 'WORKING'
                                ? Colors.green
                                : Colors.white,
                            foregroundColor: _selectedStatus == 'WORKING'
                                ? Colors.white
                                : Colors.green,
                            side: BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: _selectedStatus == 'WORKING'
                                    ? Colors.white
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'YES - Worked',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _selectedStatus = 'NOT_WORKING';
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedStatus == 'NOT_WORKING'
                                ? Colors.red
                                : Colors.white,
                            foregroundColor: _selectedStatus == 'NOT_WORKING'
                                ? Colors.white
                                : Colors.red,
                            side: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cancel,
                                size: 20,
                                color: _selectedStatus == 'NOT_WORKING'
                                    ? Colors.white
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'NO - Not Worked',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // OVERTIME SECTION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Overtime Hours',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _overtimeController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Enter overtime hours',
                        prefixIcon: const Icon(Icons.schedule),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _overtimeReasonController,
                      decoration: InputDecoration(
                        hintText: 'Reason (optional)',
                        prefixIcon: const Icon(Icons.notes),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // DEDUCTION SECTION
              Container(
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
                        Icon(Icons.remove_circle_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Deduction Hours',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deductionController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Enter deduction hours',
                        prefixIcon: const Icon(Icons.schedule),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deductionReasonController,
                      decoration: InputDecoration(
                        hintText: 'Reason (optional)',
                        prefixIcon: const Icon(Icons.notes),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAdjustments,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

