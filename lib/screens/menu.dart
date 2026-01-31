import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  String? userRole;

  @override
  void initState() {
    super.initState();
    loadRole();
  }

  Future<void> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("role") ?? "STAFF";
    });
  }

  List<Map<String, dynamic>> getMenuItems() {
    return [
      {
        "text": "Attendance",
        "icon": Icons.access_time_filled_rounded,
        "route": "/attendance",
        "roles": [ "SUPERADMIN", "ADMIN", "STAFF"]
      },
      {
        "text": "Salary Details",
        "icon": Icons.monetization_on_rounded,
        "route": "/salary-details",
        "roles": ["SUPERADMIN", "ADMIN", "STAFF"]
      },
      {
        "text": "All Users",
        "icon": Icons.group_rounded,
        "route": "/all-users",
        "roles": ["SUPERADMIN"]
      },
      {
        "text": "Attendance Report",
        "icon": Icons.access_time,
        "route": "/reports-attendance",
        "roles": ["SUPERADMIN"]
      },
      {
        "text": "Staff Salary Report",
        "icon": Icons.payments_outlined,
        "route": "/reports-salary",
        "roles": ["SUPERADMIN"]
      },
      {
        "text": "Audit Logs",
        "icon": Icons.history,
        "route": "/audit-logs",
        "roles": ["SUPERADMIN"]
      },
      {
        "text": "Idea of the Week",
        "icon": Icons.lightbulb_outline_rounded,
        "route": "/idea-of-the-week",
        "roles": ["SUPERADMIN", "ADMIN", "STAFF"]
      },
      {
        "text": "Improvements",
        "icon": Icons.build_outlined,
        "route": "/improvements",
        "roles": ["SUPERADMIN", "ADMIN", "STAFF"]
      },
      {
        "text": "Improvements Summary",
        "icon": Icons.list_alt,
        "route": "/improvements-summary",
        "roles": ["SUPERADMIN"]
      },
      {
        "text": "Ideas Summary",
        "icon": Icons.list_alt,
        "route": "/idea-of-the-week-summary",
        "roles": ["SUPERADMIN"]
      },
      {
        "text": "🔧 API Diagnostic",
        "icon": Icons.bug_report,
        "route": "/diagnostic",
        "roles": ["SUPERADMIN"]
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final items = getMenuItems()
        .where((item) => item['roles'].contains(userRole))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("OneStopSolutions"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Use PinStorage to delete pin and log out
              // ignore: use_build_context_synchronously
              await Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pushNamed(context, item['route']),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary, // ✅
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item["icon"],
                      size: 42,
                      color: Theme.of(context).colorScheme.primary, // ✅
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item["text"],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
