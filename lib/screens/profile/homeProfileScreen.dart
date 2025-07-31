    // File: lib/screens/profile/HomeProfileScreen.dart
    import 'package:flutter/material.dart';
    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:bharghavi/screens/category/categoryScreen.dart'; // Add this import

    class HomeProfileScreen extends StatefulWidget {
      const HomeProfileScreen({super.key});

      @override
      _HomeProfileScreenState createState() => _HomeProfileScreenState();
    }

    class _HomeProfileScreenState extends State<HomeProfileScreen> {
      final _formKey = GlobalKey<FormState>();
      final TextEditingController _nameController = TextEditingController();
      final TextEditingController _emailController = TextEditingController();
      final TextEditingController _phoneController = TextEditingController();

      final FirebaseAuth _auth = FirebaseAuth.instance;
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      bool _isLoading = false;

      @override
      void initState() {
        super.initState();
        _loadUserData();
      }

      @override
      void dispose() {
        _nameController.dispose();
        _emailController.dispose();
        _phoneController.dispose();
        super.dispose();
      }

      Future<void> _loadUserData() async {
        try {
          User? user = _auth.currentUser;
          if (user != null) {
            DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
            if (doc.exists) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              Map<String, dynamic> personalInfo = data['personalInfo'] ?? {};

              setState(() {
                _phoneController.text = personalInfo['phone']?.replaceAll('+91', '') ?? '';
                _nameController.text = '${personalInfo['firstName'] ?? ''} ${personalInfo['lastName'] ?? ''}'.trim();
                _emailController.text = personalInfo['email'] ?? '';
              });
            }
          }
        } catch (e) {
          print('Error loading user data: $e');
        }
      }

      Future<void> _saveProfile() async {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        setState(() {
          _isLoading = true;
        });

        try {
          User? user = _auth.currentUser;
          if (user != null) {
            // Split name into first and last name
            List<String> nameParts = _nameController.text.trim().split(' ');
            String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
            String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

            // Prepare user data
            Map<String, dynamic> userData = {
              'personalInfo': {
                'firstName': firstName,
                'lastName': lastName,
                'email': _emailController.text.trim(),
                'phone': '+91${_phoneController.text.trim()}',
              },
              'accountInfo': {
                'profileCompleted': true,  // ✅ Correct location
              },

              'updatedAt': FieldValue.serverTimestamp(),
            };

            // Save to Firestore
    // Save to Firestore
            await _firestore.collection('users').doc(user.uid).set(
              userData,
              SetOptions(merge: true),
            );

    // Verify the save was successful before navigating
            DocumentSnapshot verifyDoc = await _firestore.collection('users').doc(user.uid).get();
            if (verifyDoc.exists) {
              Map<String, dynamic> verifyData = verifyDoc.data() as Map<String, dynamic>;
              bool actuallyCompleted = verifyData['accountInfo']?['profileCompleted'] ?? false;

              if (actuallyCompleted) {
                // Navigate to CategoryScreen only if save was confirmed
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryScreen(),
                    ),
                  );
                }
              } else {
                throw Exception('Profile save verification failed');
              }
            }

            // Navigate to CategoryScreen

          }
        } catch (e) {
          print('Error saving profile: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving profile: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Complete Your Profile',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Welcome text
                    const Text(
                      'Let\'s get to know you better',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please fill in your details to personalize your experience',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Full Name Field
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.person_outline, color: Colors.orange[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters long';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Email Field
                    const Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter your email address',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.orange[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Phone Number Field
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter your phone number',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.orange[600]),
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    // Save Profile Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
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
                          'Save Profile & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }