import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widget/curvedBottomNavigationBar.dart';


class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? userData;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/getStarted', (route) => false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          userData = userDoc.data();
          _firstNameController.text = userData?['personalInfo']['firstName'] ?? '';
          _lastNameController.text = userData?['personalInfo']['lastName'] ?? '';
          _phoneController.text = userData?['personalInfo']['phone'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile. Please try again.')),
      );
    }
  }

  Future<void> _updateUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'personalInfo': {
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'phone': _phoneController.text,
          'email': user.email,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() {
        _isEditing = false;
      });
      _fetchUserData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile')),
      );
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/category', (route) => false);
        break;
      case 1:
        Navigator.pushNamedAndRemoveUntil(context, '/favorites', (route) => false);
        break;
      case 2:
        Navigator.pushNamedAndRemoveUntil(context, '/profile', (route) => false);
        break;
      case 3:
        Navigator.pushNamedAndRemoveUntil(context, '/cart', (route) => false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFE8F5E8),
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.black),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
              if (!_isEditing) _updateUserData();
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/getStarted', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        color: Color(0xFFE8F5E8),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : userData == null
            ? Center(
          child: Text(
            'No profile data available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        )
            : SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                enabled: _isEditing,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
                controller: TextEditingController(text: _auth.currentUser?.email ?? ''),
              ),
              SizedBox(height: 20),
              Text(
                'Account Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Total Orders: ${userData?['stats']['totalOrders'] ?? 0}',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Total Spent: ₹${(userData?['stats']['totalSpent'] ?? 0).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Loyalty Points: ${userData?['stats']['loyaltyPoints'] ?? 0}',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        icons: [
          Icons.home,
          Icons.favorite,
          Icons.person,
          Icons.shopping_cart,
        ],
        backgroundColor: Color(0xFF2E7D32),
        selectedColor: Colors.white,
        unselectedColor: Colors.white,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}