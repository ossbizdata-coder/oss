import 'package:OSS/screens/all_users.dart';
import 'package:flutter/material.dart';
import 'package:OSS/screens/attendence.dart';
import 'package:OSS/screens/diagnostic_screen.dart';
import 'package:OSS/screens/idea_of_the_week.dart';
import 'package:OSS/screens/idea_of_the_week_summary.dart';
import 'package:OSS/screens/improvements.dart';
import 'package:OSS/screens/improvements_summary.dart';
import 'package:OSS/screens/login.dart';
import 'package:OSS/screens/menu.dart';
import 'package:OSS/screens/my_attendance.dart';
import 'package:OSS/screens/register.dart';
import 'package:OSS/screens/my_salary.dart';
import 'package:OSS/screens/reports_attendance.dart';
import 'package:OSS/screens/reports_salary.dart';
import 'package:OSS/theme/app_theme.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_entry_screen.dart';
import 'services/pin_storage.dart';

void main() {
  runApp(const OneStopDailyApp());
}

class OneStopDailyApp extends StatelessWidget {
  const OneStopDailyApp({super.key});

  Future<Widget> _getStartScreen() async {
    final pin = await PinStorage.getPin();
    if (pin != null) {
      // Pass onPinSuccess callback for navigation
      return PinEntryScreen(onPinSuccess: () {
        // This context is valid in the MaterialApp builder
        // Use a post-frame callback to ensure navigation works
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(
            navigatorKey.currentContext!,
            "/main",
          );
        });
      });
    } else {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "OSS",
            theme: AppTheme.lightTheme,
            navigatorKey: navigatorKey,
            home: snapshot.data,
            routes: {
              "/login": (_) => const LoginScreen(),
              "/register": (_) => const RegisterScreen(),
              "/main": (_) => const MainMenu(),
              "/attendance": (_) => const AttendanceScreen(),
              "/idea-of-the-week": (_) => const IdeaOfTheWeekScreen(),
              "/idea-of-the-week-summary": (_) => const IdeaOfTheWeekSummaryScreen(),
              "/improvements": (_) => const ImprovementsScreen(),
              "/salary-details": (_) => const SalaryDetailsScreen(),
              "/my-attendance-report": (_) => const MyAttendanceReportScreen(),
              "/all-users": (_) => const AllUsersScreen(),
              "/reports-attendance": (_) => const ReportsAttendanceScreen(),
              "/reports-salary": (_) => const ReportsSalaryScreen(),
              "/improvements-summary": (_) => const ImprovementsSummaryScreen(),
              "/diagnostic": (_) => const DiagnosticScreen(),
              "/pin-setup": (_) => const PinSetupScreen(),
              "/pin-entry": (context) => PinEntryScreen(
                onPinSuccess: () {
                  Navigator.pushReplacementNamed(context, "/main");
                },
              ),
            },
          );
        }
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}

// Add a global navigatorKey to use for navigation outside of build
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
