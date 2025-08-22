import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bharghavi/screens/profile/savedAddressScreen.dart';
import 'address.dart';

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({Key? key}) : super(key: key);

  @override
  _AddressSelectionScreenState createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Address> addresses = [];
  bool isLoading = true;
  String? selectedAddressId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          List<dynamic> shippingAddresses = data['addresses']?['shipping'] ?? [];

          setState(() {
            addresses = shippingAddresses.map((addr) => Address.fromMap(addr)).toList();
            // Set default address if available, otherwise select first address
            if (addresses.isNotEmpty) {
              final Address defaultAddress = addresses.firstWhere(
                    (addr) => addr.isDefault,
                orElse: () => addresses[0], // Return first address if no default found
              );
              selectedAddressId = defaultAddress.id;
            } else {
              selectedAddressId = null;
            }
            isLoading = false;
          });
        } else {
          setState(() {
            addresses = [];
            selectedAddressId = null;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          addresses = [];
          selectedAddressId = null;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading addresses: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddEditAddress({Address? address}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAddressScreen(address: address),
      ),
    );

    if (result == true) {
      _loadAddresses();
    }
  }

  Widget _buildAddressCard(Address address) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        value: address.id,
        groupValue: selectedAddressId,
        onChanged: (value) {
          setState(() {
            selectedAddressId = value;
          });
        },
        title: Text(
          address.street,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (address.apartment.isNotEmpty)
              Text(
                address.apartment,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            Text(
              '${address.city}, ${address.state} ${address.zipCode}, ${address.country}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (address.landmark != null && address.landmark!.isNotEmpty)
              Text(
                'Landmark: ${address.landmark}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: address.type == 'home'
                ? Colors.blue.withOpacity(0.1)
                : address.type == 'work'
                ? Colors.orange.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            address.type.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: address.type == 'home'
                  ? Colors.blue
                  : address.type == 'work'
                  ? Colors.orange
                  : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF4CAF50),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Select Shipping Address',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                ),
              )
                  : addresses.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved addresses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add an address to proceed with your order',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  return _buildAddressCard(addresses[index]);
                },
              ),
            ),

            // Add Address and Continue Buttons
            Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _navigateToAddEditAddress(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Add New Address',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedAddressId == null
                          ? null
                          : () {
                        final selectedAddress = addresses.firstWhere(
                              (addr) => addr.id == selectedAddressId,
                        );
                        Navigator.pop(context, selectedAddress.toMap());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Continue to Payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}