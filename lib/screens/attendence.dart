import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pin_storage.dart';
import '../screens/my_attendance.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool isWorking = false; // Changed from hasStartedWork to isWorking
  bool loading = true;
  bool submitting = false;
  String? token;
  String workStatus = 'NOT_WORKING'; // NEW: WORKING or NOT_WORKING

  // Controllers for overtime and deduction
  final _overtimeController = TextEditingController();
  final _deductionController = TextEditingController();
  final _overtimeReasonController = TextEditingController();
  final _deductionReasonController = TextEditingController();

  static const baseUrl = "http://74.208.132.78/api/attendance";

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _overtimeController.dispose();
    _deductionController.dispose();
    _overtimeReasonController.dispose();
    _deductionReasonController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");

    if (token == null) {
      if (mounted) Navigator.pushReplacementNamed(context, "/login");
      return;
    }

    await _loadStatus();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadStatus() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/today"),
        headers: {"Authorization": "Bearer $token"},
      );

      print("DEBUG Attendance response status: ${res.statusCode}");
      print("DEBUG Attendance response body: ${res.body}");

      if (res.statusCode == 200) {
        if (res.body.isEmpty || res.body == 'null') {
          print("DEBUG No attendance record for today");
          return;
        }

        final data = jsonDecode(res.body);
        print("DEBUG Attendance today data: $data");
        setState(() {
          // Load work status
          workStatus = data["status"] ?? "NOT_WORKING";
          isWorking = (workStatus == "WORKING");

          // Load existing overtime/deduction values
          final overtime = data["overtimeHours"];
          final deduction = data["deductionHours"];

          if (overtime != null && overtime > 0) {
            _overtimeController.text = overtime.toString();
          }
          if (deduction != null && deduction > 0) {
            _deductionController.text = deduction.toString();
          }

          _overtimeReasonController.text = data["overtimeReason"] ?? '';
          _deductionReasonController.text = data["deductionReason"] ?? '';

          print("DEBUG Loaded status: $workStatus, overtime: $overtime, deduction: $deduction");
        });
      } else if (res.statusCode == 404) {
        print("DEBUG No attendance record found for today");
      }
    } catch (e) {
      print("DEBUG Error loading attendance: $e");
      print("DEBUG Error type: ${e.runtimeType}");
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// ----------------- TOGGLE WORK STATUS -----------------
  Future<void> _toggleWorkStatus(String newStatus) async {
    if (submitting) return;

    setState(() => submitting = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/mark-status"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({"status": newStatus}),
      );

      if (res.statusCode == 200) {
        setState(() {
          workStatus = newStatus;
          isWorking = (newStatus == "WORKING");
        });
        _msg("Status updated to ${newStatus == 'WORKING' ? 'Working' : 'Not Working'}");
      } else {
        final body = jsonDecode(res.body);
        _msg(body["message"] ?? "Failed to update status");
      }
    } catch (e) {
      _msg("Unable to connect to server: $e");
    } finally {
      setState(() => submitting = false);
    }
  }


  /// ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAttendanceReportScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await PinStorage.deletePin();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== QUESTION =====
            const Text(
              "Are you working today?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ===== YES/NO BUTTONS =====
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () => _toggleWorkStatus("WORKING"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWorking ? Colors.green.shade700 : Colors.green.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isWorking ? 6 : 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          "YES",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () => _toggleWorkStatus("NOT_WORKING"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isWorking ? Colors.red.shade700 : Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: !isWorking ? 6 : 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          "NO",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Current status indicator
            if (isWorking || workStatus == "NOT_WORKING") ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isWorking ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWorking ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWorking ? Icons.check_circle : Icons.cancel,
                      color: isWorking ? Colors.green.shade700 : Colors.grey.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isWorking ? "Status: Working" : "Status: Not Working",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isWorking ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ===== OVERTIME & DEDUCTION SECTION =====
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

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
                              Icon(Icons.add_circle_outline, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Overtime Hours',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _overtimeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: 'Enter overtime hours (e.g., 2.5)',
                              prefixIcon: const Icon(Icons.schedule),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _overtimeReasonController,
                            decoration: InputDecoration(
                              hintText: 'Reason (e.g., Extra project work)',
                              prefixIcon: const Icon(Icons.notes),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
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
                              Icon(Icons.remove_circle_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Deduction Hours (Out of Office)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deductionController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: 'Enter deduction hours (e.g., 1.0)',
                              prefixIcon: const Icon(Icons.schedule),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _deductionReasonController,
                            decoration: InputDecoration(
                              hintText: 'Reason (e.g., Left early)',
                              prefixIcon: const Icon(Icons.notes),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: submitting ? null : _saveAdjustments,
                        icon: const Icon(Icons.save),
                        label: submitting
                          ? const Text('Saving...')
                          : const Text('Submit'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Save overtime and deduction adjustments
  Future<void> _saveAdjustments() async {
    final overtime = double.tryParse(_overtimeController.text) ?? 0;
    final deduction = double.tryParse(_deductionController.text) ?? 0;

    if (overtime < 0 || deduction < 0) {
      _msg("Hours cannot be negative");
      return;
    }

    setState(() => submitting = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/save-adjustments"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "overtimeHours": overtime,
          "deductionHours": deduction,
          "overtimeReason": _overtimeReasonController.text.trim(),
          "deductionReason": _deductionReasonController.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        _msg("Adjustments saved successfully ✓");
        // Reload to show saved values
        await _loadStatus();
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        _msg(body["message"] ?? "Failed to save adjustments");
      }
    } catch (e) {
      _msg("Error saving adjustments: $e");
    } finally {
      setState(() => submitting = false);
    }
  }
}
