import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bharghavi/screens/profile/homeProfileScreen.dart';
import 'package:bharghavi/screens/category/categoryScreen.dart';

import 'auth/login/logInScreen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _loadingMessage = "Checking authentication...";

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      // Add a small delay for better UX
      await Future.delayed(const Duration(seconds: 1));

      User? user = _auth.currentUser;

      if (user == null) {
        // User not logged in - go to login screen
        _navigateToLogin();
        return;
      }

      setState(() {
        _loadingMessage = "Loading your profile...";
      });

      // User is logged in - check profile completion status
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // User document doesn't exist - go to profile completion
        _navigateToProfileCompletion();
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      bool profileCompleted = userData['accountInfo']?['profileCompleted'] ?? false;

      // Update last login time
      await _firestore.collection('users').doc(user.uid).update({
        'accountInfo.lastLogin': FieldValue.serverTimestamp(),
        'activity.lastActivity': FieldValue.serverTimestamp(),
      });

      setState(() {
        _loadingMessage = "Almost ready...";
      });

      // Add small delay for smoother transition
      await Future.delayed(const Duration(milliseconds: 500));

      if (profileCompleted) {
        // Profile is complete - go to main app (CategoryScreen)
        _navigateToCategoryScreen();
      } else {
        // Profile not complete - go to profile completion
        _navigateToProfileCompletion();
      }

    } catch (e) {
      print('Error checking auth state: $e');
      // On error, go to login screen
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LogInScreen()),
      );
    }
  }

  void _navigateToProfileCompletion() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeProfileScreen()),
      );
    }
  }

  void _navigateToCategoryScreen() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CategoryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6FFE6),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Section
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 50,
                ),
              ),

              const SizedBox(height: 30),

              // Company Name
              const Text(
                'Bhargavi Enterprises',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1b622c),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'India\'s Healthiest products',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Loading Indicator
              Container(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.green.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Loading Message
              Text(
                _loadingMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// Update your main.dart to use AuthWrapper as the initial screen
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhargavi Enterprises',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(), // Use AuthWrapper instead of LogInScreen
      debugShowCheckedModeBanner: false,
    );
  }
}

// Alternative: If you want to use StreamBuilder for real-time auth state changes
class AuthWrapperWithStream extends StatelessWidget {
  const AuthWrapperWithStream({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSplashScreen("Checking authentication...");
        }

        // User not logged in
        if (snapshot.data == null) {
          return LogInScreen();
        }

        // User is logged in - check profile completion
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildSplashScreen("Loading your profile...");
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return HomeProfileScreen();
            }

            Map<String, dynamic> userData =
            userSnapshot.data!.data() as Map<String, dynamic>;
            bool profileCompleted =
                userData['accountInfo']?['profileCompleted'] ?? false;

            // Update last login
            FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .update({
              'accountInfo.lastLogin': FieldValue.serverTimestamp(),
              'activity.lastActivity': FieldValue.serverTimestamp(),
            });

            return profileCompleted ? CategoryScreen() : HomeProfileScreen();
          },
        );
      },
    );
  }

  Widget _buildSplashScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6FFE6),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Bhargavi Enterprises',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1b622c),
                ),
              ),
              const SizedBox(height: 60),
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}