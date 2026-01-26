import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pin_storage.dart';
import 'user_attendance_editor.dart';

const String apiBaseUrl = "http://74.208.132.78/api";

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  String? token;
  int? updatingUserId;
  String? errorMsg;
  String? currentUserRole; // Track current user's role

  @override
  void initState() {
    super.initState();
    loadTokenAndFetchUsers();
  }

  void loadTokenAndFetchUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("token");
    final role = prefs.getString("role");
    setState(() {
      token = t;
      currentUserRole = role;
    });
    fetchUsers(t);
  }

  void fetchUsers(String? t) async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      final res = await http.get(
        Uri.parse("$apiBaseUrl/users"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $t",
        },
      );
      if (res.statusCode == 200) {
        setState(() {
          users = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMsg = "Failed to load users: ${res.body}";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMsg = "Error: $e";
      });
    }
  }

  void updateRole(int userId, String newRole) async {
    setState(() => updatingUserId = userId);
    try {
      final res = await http.put(
        Uri.parse("$apiBaseUrl/auth/users/$userId/role"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"role": newRole}),
      );
      if (res.statusCode == 200) {
        fetchUsers(token);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Role updated successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => updatingUserId = null);
    }
  }

  void _showEditSalaryDialog(Map<String, dynamic> user) {
    final dailySalaryController = TextEditingController(
      text: (user["dailySalary"] ?? 0).toString(),
    );
    final hourlyRateController = TextEditingController(
      text: (user["hourlyRate"] ?? 0).toString(),
    );
    final deductionRateController = TextEditingController(
      text: (user["deductionRatePerHour"] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Salary - ${user["name"]}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dailySalaryController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Daily Salary',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hourlyRateController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Hourly Rate (Overtime)',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deductionRateController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Deduction Rate per Hour',
                  prefixIcon: Icon(Icons.remove_circle_outline),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dailySalary = double.tryParse(dailySalaryController.text) ?? 0;
              final hourlyRate = double.tryParse(hourlyRateController.text) ?? 0;
              final deductionRate = double.tryParse(deductionRateController.text) ?? 0;

              Navigator.pop(ctx);
              await _updateUserSalary(user["id"], dailySalary, hourlyRate, deductionRate);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserSalary(int userId, double dailySalary, double hourlyRate, double deductionRate) async {
    try {
      final res = await http.put(
        Uri.parse("$apiBaseUrl/users/$userId/salary"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "dailySalary": dailySalary,
          "hourlyRate": hourlyRate,
          "deductionRatePerHour": deductionRate,
        }),
      );

      if (res.statusCode == 200) {
        fetchUsers(token);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Salary updated successfully ✓")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget userCard(Map<String, dynamic> user) {
    final isSuperAdmin = currentUserRole == "SUPERADMIN";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user["name"] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user["email"] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isSuperAdmin) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Daily: ${user["dailySalary"] ?? 0}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Hourly: ${user["hourlyRate"] ?? 0}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Role dropdown
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: updatingUserId == user["id"]
                      ? const SizedBox(
                          height: 32,
                          width: 32,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : DropdownButton<String>(
                          isExpanded: true,
                          value: ["SUPERADMIN", "ADMIN", "STAFF", "CUSTOMER"].contains(user["role"])
                              ? user["role"]
                              : "CUSTOMER",
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: ["SUPERADMIN", "ADMIN", "STAFF", "CUSTOMER"]
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null && val != user["role"]) {
                              updateRole(user["id"], val);
                            }
                          },
                        ),
                ),
              ),
            ],
          ),
          // Superadmin action buttons
          if (isSuperAdmin) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserAttendanceEditorScreen(
                            userId: user["id"],
                            userName: user["name"] ?? '',
                            token: token!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Edit Attendance'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditSalaryDialog(user),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Salary'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Users"),
        actions: [
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
          : errorMsg != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => fetchUsers(token),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : users.isEmpty
                  ? const Center(child: Text("No users found"))
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: ListView(
                        children: users.map((u) => userCard(u)).toList(),
                      ),
                    ),
    );
  }
}
