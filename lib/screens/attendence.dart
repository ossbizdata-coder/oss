import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pin_storage.dart';
import '../widgets/primary_button.dart';
import '../screens/my_attendance.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool hasStartedWork = false;
  bool loading = true;
  bool submitting = false;
  String? token;
  DateTime? _lastCheckInTime;

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
          hasStartedWork = data["status"] == "CHECKED_IN";
          if (data["checkInTime"] != null) {
            _lastCheckInTime = DateTime.parse(data["checkInTime"]).toLocal();
          }

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

          print("DEBUG Loaded overtime: $overtime, deduction: $deduction");
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

  bool _checkInAllowed(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    return m >= 375 && m <= 1170; // 6:15 AM – 7:30 PM
  }

  bool _checkOutAllowed(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    return m <= 1230; // until 8:30 PM
  }

  /// ----------------- CHECK-IN -----------------
  Future<void> startWork({DateTime? manualTime}) async {
    if (submitting || hasStartedWork) {
      _msg("You have already checked in today");
      return;
    }

    final now = manualTime ?? DateTime.now();
    if (!_checkInAllowed(TimeOfDay.fromDateTime(now))) {
      _msg("Check-in allowed 6:15 AM – 7:30 PM");
      return;
    }

    setState(() => submitting = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/check-in"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({"checkInTime": now.toUtc().toIso8601String()}),
      );

      if (res.statusCode == 200) {
        setState(() {
          hasStartedWork = true;
          _lastCheckInTime = now;
        });
        _msg(manualTime != null ? "Manual check-in saved" : "Checked in successfully");
      } else {
        final body = jsonDecode(res.body);
        _msg(body["message"] ?? "Check-in failed");
      }
    } catch (e) {
      _msg("Unable to connect to server: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  Future<void> _pickManualCheckIn() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      final now = DateTime.now();
      final manualTime = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      await startWork(manualTime: manualTime);
    }
  }

  /// ----------------- CHECK-OUT -----------------
  Future<void> endWork({DateTime? manualTime}) async {
    if (submitting || !hasStartedWork) return;

    final now = manualTime ?? DateTime.now();
    if (!_checkOutAllowed(TimeOfDay.fromDateTime(now))) {
      _msg("Checkout allowed until 8:30 PM");
      return;
    }

    if (_lastCheckInTime != null && !now.isAfter(_lastCheckInTime!)) {
      _msg("Checkout must be after check-in");
      return;
    }

    setState(() => submitting = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/check-out"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({"checkOutTime": now.toUtc().toIso8601String()}),
      );

      if (res.statusCode == 200) {
        setState(() => hasStartedWork = false);
        _msg(manualTime != null ? "Manual checkout saved" : "Checked out successfully");
      } else {
        final body = jsonDecode(res.body);
        _msg(body["message"] ?? "Checkout failed");
      }
    } catch (e) {
      _msg("Unable to connect to server: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  Future<void> _pickManualCheckOut() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      final now = DateTime.now();
      final manualTime = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      await endWork(manualTime: manualTime);
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
            if (_lastCheckInTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Checked in at: ${TimeOfDay.fromDateTime(_lastCheckInTime!).format(context)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            // ===== CHECK-IN ROW =====
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: "Check In",
                    onPressed: (!hasStartedWork && !submitting) ? () => startWork() : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.schedule),
                  tooltip: "Manual Check In",
                  onPressed: (!hasStartedWork && !submitting) ? _pickManualCheckIn : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ===== CHECK-OUT ROW =====
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: "Check Out",
                    onPressed: (hasStartedWork && !submitting) ? () => endWork() : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.schedule),
                  tooltip: "Manual Check Out",
                  onPressed: (hasStartedWork && !submitting) ? _pickManualCheckOut : null,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ===== OVERTIME & DEDUCTION SECTION =====
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with refresh
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Adjustments",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadStatus,
                          tooltip: 'Refresh saved values',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Add overtime or deduction hours for today",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

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

    if (overtime == 0 && deduction == 0) {
      _msg("Please enter overtime or deduction hours");
      return;
    }

    setState(() => submitting = true);

    try {
      // First get today's attendance ID
      final res = await http.get(
        Uri.parse("$baseUrl/today"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode != 200) {
        _msg("Could not fetch today's attendance");
        return;
      }

      final data = jsonDecode(res.body);
      final attendanceId = data['id'];

      if (attendanceId == null) {
        _msg("No attendance record found for today");
        return;
      }

      // Save adjustments
      final adjustRes = await http.put(
        Uri.parse("$baseUrl/$attendanceId/adjustments"),
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

      if (adjustRes.statusCode == 200) {
        _msg("Adjustments saved successfully ✓");
        // Reload to show saved values
        await _loadStatus();
      } else {
        _msg("Failed to save adjustments: ${adjustRes.body}");
      }
    } catch (e) {
      _msg("Error saving adjustments: $e");
    } finally {
      setState(() => submitting = false);
    }
  }
}
