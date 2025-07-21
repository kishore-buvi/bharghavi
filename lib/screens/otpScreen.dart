//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:pinput/pinput.dart';
//
// import 'homeScreen.dart';
//
// class OTPScreen extends StatefulWidget {
//   final String verificationId;
//   final String phoneNumber;
//
//   OTPScreen({required this.verificationId, required this.phoneNumber});
//
//   @override
//   _OTPScreenState createState() => _OTPScreenState();
// }
//
// class _OTPScreenState extends State<OTPScreen> {
//   final _otpController = TextEditingController();
//   final _auth = FirebaseAuth.instance;
//   final _firestore = FirebaseFirestore.instance;
//   bool _isInvalidOTP = false;
//   bool _isVerifying = false;
//
//   Future<void> verifyOTP() async {
//     if (_otpController.text.length != 6) {
//       setState(() {
//         _isInvalidOTP = true;
//       });
//       return;
//     }
//
//     setState(() {
//       _isVerifying = true;
//       _isInvalidOTP = false;
//     });
//
//     try {
//       PhoneAuthCredential credential = PhoneAuthProvider.credential(
//         verificationId: widget.verificationId,
//         smsCode: _otpController.text,
//       );
//
//       UserCredential userCredential = await _auth.signInWithCredential(credential);
//
//       if (userCredential.user != null) {
//         // Write user data to Firestore
//         await _firestore.collection('users').doc(userCredential.user!.uid).set({
//           'phoneNumber': '+91${widget.phoneNumber}',
//           'createdAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//
//         // Navigate to home screen on success
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Login successful'))
//           );
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => HomeScreen()),
//           );
//         }
//       }
//     } catch (e) {
//       print('OTP Verification Error: $e');
//       if (mounted) {
//         setState(() {
//           _isInvalidOTP = true;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Invalid OTP. Please try again.'))
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isVerifying = false;
//         });
//       }
//     }
//   }
//
//   Future<void> resendOTP() async {
//     try {
//       await _auth.verifyPhoneNumber(
//         phoneNumber: '+91${widget.phoneNumber}',
//         verificationCompleted: (PhoneAuthCredential credential) async {
//           await _auth.signInWithCredential(credential);
//         },
//         verificationFailed: (FirebaseAuthException e) {
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(e.message ?? 'Verification failed'))
//             );
//           }
//         },
//         codeSent: (String verificationId, int? resendToken) {
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('OTP resent successfully'))
//             );
//           }
//         },
//         codeAutoRetrievalTimeout: (String verificationId) {},
//       );
//     } catch (e) {
//       print('Resend OTP Error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Failed to resend OTP. Please try again.'))
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Verify OTP'),
//         backgroundColor: Color(0xFFE6FFE6),
//       ),
//       body: Container(
//         color: Color(0xFFE6FFE6),
//         child: Center(
//           child: SingleChildScrollView(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Image.asset(
//                   'assets/otp_illustration.png',
//                   height: 200,
//                   errorBuilder: (context, error, stackTrace) {
//                     return Icon(Icons.phone_android, size: 100, color: Colors.green);
//                   },
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'We\'ve sent a verification code to',
//                   style: TextStyle(fontSize: 16),
//                   textAlign: TextAlign.center,
//                 ),
//                 Text(
//                   '+91 ${widget.phoneNumber}',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 30),
//                 Pinput(
//                   length: 6,
//                   controller: _otpController,
//                   defaultPinTheme: PinTheme(
//                     width: 50,
//                     height: 50,
//                     textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: _isInvalidOTP ? Colors.red : Colors.black),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   focusedPinTheme: PinTheme(
//                     width: 50,
//                     height: 50,
//                     textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.green, width: 2),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   onCompleted: (pin) {
//                     if (pin.length == 6) {
//                       verifyOTP();
//                     }
//                   },
//                   onChanged: (value) {
//                     if (_isInvalidOTP) {
//                       setState(() {
//                         _isInvalidOTP = false;
//                       });
//                     }
//                   },
//                 ),
//                 if (_isInvalidOTP)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 10),
//                     child: Text(
//                       'Invalid OTP. Please try again.',
//                       style: TextStyle(color: Colors.red, fontSize: 14),
//                     ),
//                   ),
//                 SizedBox(height: 20),
//                 TextButton(
//                   onPressed: resendOTP,
//                   child: Text(
//                     'Don\'t receive the OTP? Resend OTP',
//                     style: TextStyle(color: Colors.orange, fontSize: 16),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: _isVerifying ? null : verifyOTP,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     minimumSize: Size(200, 50),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: _isVerifying
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Verify', style: TextStyle(fontSize: 16)),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }