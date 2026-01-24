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

  @override
  void initState() {
    super.initState();
    // Pre-fill if values exist
    final overtime = widget.attendance['overtimeHours'] ?? 0;
    final deduction = widget.attendance['deductionHours'] ?? 0;

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

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final attendanceId = widget.attendance['id'];

      final response = await http.put(
        Uri.parse('http://74.208.132.78/api/attendance/$attendanceId/adjustments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'overtimeHours': overtime,
          'deductionHours': deduction,
          'overtimeReason': _overtimeReasonController.text.trim(),
          'deductionReason': _deductionReasonController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adjustments saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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
    final totalMinutes = widget.attendance['totalMinutes'] ?? 0;
    final hours = totalMinutes / 60.0;

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
                          ? DateFormat.yMMMd().format(DateTime.parse(workDate))
                          : 'Unknown date',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${hours.toStringAsFixed(1)} hours worked',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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

