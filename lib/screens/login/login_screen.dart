import 'package:flutter/material.dart';
// import '../api/api_service.dart';
import '../../api/api_constants.dart';
import '../../api/auth_repository.dart';
import '../../theme.dart';
import '../home/home_screen.dart';
import '../employee/employee_dashboard_screen.dart';
import '../../utils/jwt_decoder.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import '../register/register_pump_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sapController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _sapController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    developer.log('_authenticate() called with: email=${_emailController.text}, password length=${_passwordController.text.length} chars, sap=${_sapController.text}');
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    final authRepository = AuthRepository();
    
    try {
      developer.log('Making login API call to: ${ApiConstants.getLoginUrl()}');
      
      // Use direct auth repository call without additional timeout
      final response = await authRepository.login(
        _emailController.text,
        _passwordController.text,
        _sapController.text,
      );

      developer.log('Login API response received: success=${response.success}, message=${response.errorMessage}, hasData=${response.data != null}');

      if (response.success) {
        // Store the token in SharedPreferences
        final token = response.data?['token'];
        developer.log('Token received: ${token != null ? 'Yes' : 'No'}');
        
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(ApiConstants.authTokenKey, token);
          developer.log('Token stored in SharedPreferences');
          
          // Decode the JWT token to get user claims
          Map<String, dynamic>? claims;
          String? userId;
          String? userRole;
          
          try {
            // Import the JwtDecoder to decode the token
            claims = JwtDecoder.decode(token);
            developer.log('JWT token decoded successfully: ${claims != null ? 'Yes' : 'No'}');
            
            if (claims != null) {
              // Extract userId from claims
              userId = JwtDecoder.getClaim<String>(token, 'userId') ?? 
                      JwtDecoder.getClaim<String>(token, 'sub') ??
                      JwtDecoder.getClaim<String>(token, 'id');
              
              // Extract user role from claims
              userRole = JwtDecoder.getClaim<String>(token, 'role') ?? 
                        JwtDecoder.getClaim<String>(token, 'userRole') ??
                        JwtDecoder.getClaim<String>(token, 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role');
              
              developer.log('Extracted userId: $userId, userRole: $userRole');
              
              // Store userId and role in SharedPreferences for later use
              if (userId != null) {
                await prefs.setString('userId', userId);
                developer.log('UserId stored in SharedPreferences');
              }
              
              if (userRole != null) {
                await prefs.setString('userRole', userRole);
                developer.log('UserRole stored in SharedPreferences');
              }
            }
          } catch (e) {
            developer.log('Error decoding JWT token: $e');
            // Continue even if token decoding fails - default to home screen
          }

          if (!mounted) {
            developer.log('Widget not mounted after login API call');
            return;
          }
          
          // Redirect based on user role
          if (userRole != null) {
            final lowerRole = userRole.toLowerCase();
            developer.log('Redirecting user based on role: $lowerRole');
            
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
            developer.log('No role found in token, navigating to HomeScreen');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        } else {
          developer.log('ERROR: Token is null in successful response');
          _errorMessage = 'Authentication successful but no token received';
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful but no token received. This is unusual.')),
          );
          
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else {
        // Show error message
        if (!mounted) {
          developer.log('Widget not mounted after login API call');
          return;
        }
        
        final errorMsg = response.errorMessage ?? ApiConstants.someThingWentWrong;
        developer.log('Showing error message: $errorMsg');
        
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (error) {
      // Handle any errors
      developer.log('Exception caught in _authenticate(): $error');
      
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // form
  void _submitForm() {
    developer.log('_submitForm() called');
    if (_formKey.currentState!.validate()) {
      developer.log('Form validation passed, calling _authenticate()');
      _authenticate();
    } else {
      developer.log('Form validation failed');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withValues(alpha:0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo and Branding
                      Align(
                        alignment: Alignment.center,
                        child: Hero(
                          tag: 'logo',
                          child: Container(
                            height: 100,
                            width: 100,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:0.1),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Welcome Text
                      Text(
                        'Welcome Back',
                        style: AppTheme.headingStyle.copyWith(
                          fontSize: 28,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black.withValues(alpha:0.2),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        style: AppTheme.subheadingStyle.copyWith(
                          color: Colors.white.withValues(alpha:0.9),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Login Card
                      Card(
                        elevation: 10,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Form Title
                                Text(
                                  'Login',
                                  style: AppTheme.subheadingStyle.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email / Phone',
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 1.5,
                                      ),
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible = !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 1.5,
                                      ),
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // SAP Field
                                TextFormField(
                                  controller: _sapController,
                                  keyboardType: TextInputType.visiblePassword,
                                  decoration: InputDecoration(
                                    labelText: 'SAP ID',
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 1.5,
                                      ),
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                                
                                // Error Message
                                if (_errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                const SizedBox(height: 32),
                                
                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 3,
                                      shadowColor: AppTheme.primaryBlue.withValues(alpha:0.5),
                                      disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha:0.6),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Register Button
                      TextButton.icon(
                        onPressed: _isLoading ? null : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RegisterPumpScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.add_business_outlined,
                          color: AppTheme.primaryOrange,
                        ),
                        label: Text(
                          'Register a New Pump',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}