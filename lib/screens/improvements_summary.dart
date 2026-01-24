import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImprovementsSummaryScreen extends StatefulWidget {
  const ImprovementsSummaryScreen({super.key});

  @override
  State<ImprovementsSummaryScreen> createState() =>
      _ImprovementsSummaryScreenState();
}

class _ImprovementsSummaryScreenState
    extends State<ImprovementsSummaryScreen> {
  List<dynamic> improvements = [];
  bool loading = true;
  String? error;

  final dateFmt = DateFormat('dd MMM yyyy • hh:mm a');

  @override
  void initState() {
    super.initState();
    fetchImprovements();
  }

  Future<void> fetchImprovements() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('http://74.208.132.78/api/messages/improvement'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        setState(() {
          improvements = jsonDecode(res.body);
          loading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load improvements';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Improvements'),
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
            onPressed: loading ? null : fetchImprovements,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : improvements.isEmpty
          ? const Center(child: Text('No improvements submitted'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: improvements.length,
        itemBuilder: (context, index) {
          final imp = improvements[index];
          final user = imp['user'];
          final date = imp['createdAt'] != null
              ? DateTime.parse(imp['createdAt'])
              .toUtc()
              .toLocal()
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((Colors.black.a * 0.05).toInt()),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// MESSAGE
                Text(
                  imp['message'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 14),

                /// FOOTER
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    _userChip(
                      primary,
                      user?['name'] ?? 'Unknown',
                    ),
                    Text(
                      date != null
                          ? dateFmt.format(date)
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _userChip(Color color, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((color.a * 0.1).toInt()),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
