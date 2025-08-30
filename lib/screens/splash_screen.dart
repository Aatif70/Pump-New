import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../api/api_constants.dart';
import '../theme.dart';
import 'home/home_screen.dart';
import 'login/login_screen.dart';
import 'employee/employee_dashboard_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Add a small delay to show the splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if user is already logged in
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.authTokenKey);
    
    if (!mounted) return;
    
    // Navigate to appropriate screen based on auth status
    if (token != null && token.isNotEmpty) {
      // User is logged in, check role to determine destination
      final userRole = prefs.getString('userRole');
      developer.log('Found user role in SharedPreferences: $userRole');
      
      if (userRole != null) {
        final lowerRole = userRole.toLowerCase();
        
        if (lowerRole == 'manager' || lowerRole == 'admin') {
          // Navigate to HomeScreen for managers and admins
          developer.log('Navigating to HomeScreen (manager/admin)');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        } else if (lowerRole == 'attendant' || lowerRole == 'employee') {
          // Navigate to EmployeeDashboardScreen for attendants and employees
          developer.log('Navigating to EmployeeDashboardScreen (attendant/employee)');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const EmployeeDashboardScreen(),
            ),
          );
        } else {
          // Default to HomeScreen for unknown roles
          developer.log('Navigating to HomeScreen (unknown role)');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      } else {
        // If role not found, default to HomeScreen
        developer.log('No role found, navigating to HomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // User is not logged in, go to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo.jpg',
              height: 150,
              width: 150,
            ),
            const SizedBox(height: 32),
            
            // App Name
            Text(
              ApiConstants.appName,
              style: AppTheme.headingStyle.copyWith(
                fontSize: 28,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
} 