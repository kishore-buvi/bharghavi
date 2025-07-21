// // otpScreen.dart
//
// // loginScreen.dart
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'homeScreen.dart';
// import 'otpScreen.dart';
//
// class LoginScreen extends StatefulWidget {
//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _phoneController = TextEditingController();
//   final _auth = FirebaseAuth.instance;
//   bool _isSendingOTP = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _phoneController.addListener(() {
//       setState(() {}); // Rebuild UI when text changes
//     });
//   }
//
//   @override
//   void dispose() {
//     _phoneController.dispose();
//     super.dispose();
//   }
//
//   Future<void> sendOTP(String phoneNumber) async {
//     setState(() {
//       _isSendingOTP = true;
//     });
//
//     try {
//       await _auth.verifyPhoneNumber(
//         phoneNumber: '+91$phoneNumber',
//         verificationCompleted: (PhoneAuthCredential credential) async {
//           // Auto-verification (Android only)
//           try {
//             await _auth.signInWithCredential(credential);
//             if (mounted) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Phone number verified automatically'))
//               );
//               // Navigate to home screen directly
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (_) => HomeScreen()),
//               );
//             }
//           } catch (e) {
//             print('Auto verification error: $e');
//           }
//         },
//         verificationFailed: (FirebaseAuthException e) {
//           print('Verification failed: ${e.code} - ${e.message}');
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(e.message ?? 'Verification failed'))
//             );
//           }
//         },
//         codeSent: (String verificationId, int? resendToken) {
//           if (mounted) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => OTPScreen(
//                   verificationId: verificationId,
//                   phoneNumber: phoneNumber,
//                 ),
//               ),
//             );
//           }
//         },
//         codeAutoRetrievalTimeout: (String verificationId) {
//           print('Auto retrieval timeout: $verificationId');
//         },
//         timeout: Duration(seconds: 60),
//       );
//     } catch (e) {
//       print('Send OTP Error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Failed to send OTP. Please try again.'))
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSendingOTP = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         color: Color(0xFFE6FFE6),
//         child: Center(
//           child: SingleChildScrollView(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Image.asset(
//                   'assets/logo.png',
//                   height: 100,
//                   errorBuilder: (context, error, stackTrace) {
//                     return Icon(Icons.business, size: 100, color: Colors.green);
//                   },
//                 ),
//                 SizedBox(height: 10),
//                 Text(
//                   'Bhargavi Enterprises',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   'India\'s Healthiest products',
//                   style: TextStyle(fontSize: 16),
//                 ),
//                 SizedBox(height: 40),
//                 TextField(
//                   controller: _phoneController,
//                   keyboardType: TextInputType.phone,
//                   maxLength: 10,
//                   decoration: InputDecoration(
//                     labelText: 'Phone number',
//                     hintText: 'Enter 10-digit phone number',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     prefixText: '+91 ',
//                     counterText: '',
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: (_phoneController.text.length == 10 && !_isSendingOTP)
//                       ? () => sendOTP(_phoneController.text)
//                       : null,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     minimumSize: Size(200, 50),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: _isSendingOTP
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Continue', style: TextStyle(fontSize: 16)),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }