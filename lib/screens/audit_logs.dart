import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class AuditLog {
  final int id;
  final String action;
  final String entityType;
  final String? entityId;
  final String performedBy;
  final DateTime timestamp;
  final String? details;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;

  AuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.performedBy,
    required this.timestamp,
    this.details,
    this.oldValue,
    this.newValue,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    // Try multiple field names for the user who performed the action
    String performedByUser = 'System';
    if (json['performedBy'] != null) {
      performedByUser = json['performedBy'].toString();
    } else if (json['userName'] != null) {
      performedByUser = json['userName'].toString();
    } else if (json['user'] != null) {
      if (json['user'] is Map) {
        performedByUser = json['user']['name']?.toString() ??
                         json['user']['username']?.toString() ??
                         json['user']['email']?.toString() ??
                         'User #${json['user']['id']}';
      } else {
        performedByUser = json['user'].toString();
      }
    } else if (json['performedByUserId'] != null) {
      performedByUser = 'User #${json['performedByUserId']}';
    }

    return AuditLog(
      id: json['id'] ?? 0,
      action: json['action'] ?? 'UNKNOWN',
      entityType: json['entityType'] ?? 'UNKNOWN',
      entityId: json['entityId']?.toString(),
      performedBy: performedByUser,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      details: json['details']?.toString(),
      oldValue: json['oldValue'] != null
          ? (json['oldValue'] is String
              ? jsonDecode(json['oldValue'])
              : json['oldValue'])
          : null,
      newValue: json['newValue'] != null
          ? (json['newValue'] is String
              ? jsonDecode(json['newValue'])
              : json['newValue'])
          : null,
    );
  }

  String getSimplifiedTitle() {
    return '$action $entityType';
  }
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLog> allLogs = [];
  List<AuditLog> filteredLogs = [];
  bool loading = true;
  String? error;
  String searchQuery = '';
  String selectedAction = 'ALL';
  String selectedEntity = 'ALL';
  DateTime selectedDate = DateTime.now();

  final List<String> actionTypes = [
    'ALL',
    'CREATE',
    'UPDATE',
    'DELETE',
    'LOGIN',
    'LOGOUT',
    'CHECK_IN',
    'CHECK_OUT',
  ];

  final List<String> entityTypes = [
    'ALL',
    'USER',
    'ATTENDANCE',
    'SALARY',
    'CREDIT',
    'IDEA',
    'IMPROVEMENT',
  ];

  @override
  void initState() {
    super.initState();
    fetchAuditLogs();
  }

  Future<void> fetchAuditLogs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final role = prefs.getString("role");

      if (role != "SUPERADMIN") {
        setState(() {
          error = "Access denied: Super Admins only";
          loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://74.208.132.78/api/audit-logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Debug: Print first log entry to see the structure
        if (data.isNotEmpty) {
          print('DEBUG Audit Log - First entry structure: ${data[0]}');
          print('DEBUG Audit Log - performedBy field: ${data[0]['performedBy']}');
          print('DEBUG Audit Log - All keys: ${(data[0] as Map).keys.toList()}');
        }

        setState(() {
          allLogs = data.map((json) => AuditLog.fromJson(json)).toList();
          applyFilters();
          loading = false;
        });
      } else {
        setState(() {
          error = "Failed to load audit logs: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error loading audit logs: $e";
        loading = false;
      });
    }
  }

  void applyFilters() {
    filteredLogs = allLogs.where((log) {
      final matchesSearch = searchQuery.isEmpty ||
          log.action.toLowerCase().contains(searchQuery.toLowerCase()) ||
          log.entityType.toLowerCase().contains(searchQuery.toLowerCase()) ||
          log.performedBy.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (log.details?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);

      final matchesAction = selectedAction == 'ALL' || log.action == selectedAction;
      final matchesEntity = selectedEntity == 'ALL' || log.entityType == selectedEntity;

      final logDate = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      final filterDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final matchesDate = logDate.isAtSameMomentAs(filterDate);

      return matchesSearch && matchesAction && matchesEntity && matchesDate;
    }).toList();

    filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        applyFilters();
      });
    }
  }

  void previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      applyFilters();
    });
  }

  void nextDay() {
    final tomorrow = selectedDate.add(const Duration(days: 1));
    if (!tomorrow.isAfter(DateTime.now())) {
      setState(() {
        selectedDate = tomorrow;
        applyFilters();
      });
    }
  }

  void goToToday() {
    setState(() {
      selectedDate = DateTime.now();
      applyFilters();
    });
  }

  String formatTimestamp(DateTime timestamp) {
    return DateFormat('dd MMM yyyy HH:mm:ss').format(timestamp);
  }

  Color getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
      case 'EDIT':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'LOGIN':
        return Colors.purple;
      case 'LOGOUT':
        return Colors.orange;
      case 'CHECK_IN':
        return Colors.teal;
      case 'CHECK_OUT':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle_outline;
      case 'UPDATE':
      case 'EDIT':
        return Icons.edit_outlined;
      case 'DELETE':
        return Icons.delete_outline;
      case 'LOGIN':
        return Icons.login;
      case 'LOGOUT':
        return Icons.logout;
      case 'CHECK_IN':
        return Icons.check_circle;
      case 'CHECK_OUT':
        return Icons.exit_to_app;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAuditLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Navigation Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: previousDay,
                  tooltip: 'Previous Day',
                ),
                Expanded(
                  child: InkWell(
                    onTap: selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: nextDay,
                  tooltip: 'Next Day',
                ),
                IconButton(
                  icon: const Icon(Icons.today, color: Colors.white),
                  onPressed: goToToday,
                  tooltip: 'Today',
                ),
              ],
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      applyFilters();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedAction,
                        decoration: InputDecoration(
                          labelText: 'Action',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: actionTypes.map((action) {
                          return DropdownMenuItem(
                            value: action,
                            child: Text(action, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedAction = value ?? 'ALL';
                            applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedEntity,
                        decoration: InputDecoration(
                          labelText: 'Entity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: entityTypes.map((entity) {
                          return DropdownMenuItem(
                            value: entity,
                            child: Text(entity, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedEntity = value ?? 'ALL';
                            applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Bar
          if (!loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredLogs.length} ${filteredLogs.length == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (searchQuery.isNotEmpty || selectedAction != 'ALL' || selectedEntity != 'ALL')
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear Filters'),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                          selectedAction = 'ALL';
                          selectedEntity = 'ALL';
                          applyFilters();
                        });
                      },
                    ),
                ],
              ),
            ),

          // Logs List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'Error Loading Logs',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error!,
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: fetchAuditLogs,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No audit logs found',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try selecting a different date or clearing filters',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchAuditLogs,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                final actionColor = getActionColor(log.action);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: actionColor,
                                      radius: 20,
                                      child: Icon(
                                        getActionIcon(log.action),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: actionColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            log.action,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            log.entityType,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'By: ${log.performedBy}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('HH:mm:ss').format(log.timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (log.entityId != null) ...[
                                              _buildDetailRow('Entity ID', log.entityId!),
                                              const SizedBox(height: 8),
                                            ],
                                            if (log.details != null && log.details!.isNotEmpty) ...[
                                              _buildDetailRow('Details', log.details!),
                                              const SizedBox(height: 8),
                                            ],
                                            _buildDetailRow('Full Timestamp', formatTimestamp(log.timestamp)),

                                            // Show old/new values comparison
                                            if (log.oldValue != null || log.newValue != null) ...[
                                              const SizedBox(height: 16),
                                              const Divider(),
                                              const SizedBox(height: 12),
                                              if (log.oldValue != null) ...[
                                                const Text(
                                                  'Previous Values:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                _buildValueDisplay(log.oldValue!, Colors.red.shade50),
                                                const SizedBox(height: 12),
                                              ],
                                              if (log.newValue != null) ...[
                                                const Text(
                                                  'New Values:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                _buildValueDisplay(log.newValue!, Colors.green.shade50),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValueDisplay(Map<String, dynamic> values, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: values.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    '${entry.key}:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatValue(entry.value),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return value.toString();
    if (value is String) return value;
    return jsonEncode(value);
  }
}

