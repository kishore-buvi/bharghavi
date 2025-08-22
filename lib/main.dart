import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'authWrapper.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    // For Android: Use debug for development, playIntegrity for production
    androidProvider: AndroidProvider.debug,  // Switch to AndroidProvider.playIntegrity in production
    // For iOS (if applicable): AppleProvider.appAttest or .deviceCheck
    // appleProvider: AppleProvider.debug,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(), // Use AuthWrapper instead of GetStartPage
    );
  }
}