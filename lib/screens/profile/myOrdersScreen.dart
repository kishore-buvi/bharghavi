import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For formatting dates

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  _MyOrdersScreenState createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot querySnapshot = await _firestore
            .collection('orders')
            .where('customer.userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true) // Changed from orderDate to createdAt
            .get();

        setState(() {
          orders = querySnapshot.docs
              .map((doc) => {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          })
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          orders = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderDate = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(); // Changed from orderDate to createdAt
    final formattedDate = DateFormat('MMM dd, yyyy – hh:mm a').format(orderDate);
    final totalAmount = order['totalAmount']?.toStringAsFixed(2) ?? '0.00';
    final status = order['status'] ?? 'Pending';
    final items = order['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['id'].substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Delivered'
                        ? Colors.green.withOpacity(0.1)
                        : status == 'Processing'
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status == 'Delivered'
                          ? Colors.green
                          : status == 'Processing'
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: $formattedDate',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ₹$totalAmount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Items: ${items.length}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Navigate to order details or show details in a dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Order #${order['id'].substring(0, 8)} Details'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Date: $formattedDate'),
                          Text('Total: ₹$totalAmount'),
                          Text('Status: $status'),
                          const SizedBox(height: 8),
                          const Text(
                            'Items:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          ...items.map((item) => Text(
                            '- ${item['name']} (Qty: ${item['quantity']}, ₹${item['price'].toStringAsFixed(2)})',
                            style: TextStyle(color: Colors.grey[700]),
                          )),
                          const SizedBox(height: 8),
                          const Text(
                            'Shipping Address:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${order['shippingAddress']['street']}, ${order['shippingAddress']['city']}, '
                                '${order['shippingAddress']['state']} ${order['shippingAddress']['zipCode']}, '
                                '${order['shippingAddress']['country']}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'View Details',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
                      'My Orders',
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
                  : orders.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Place an order to see it here',
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
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(orders[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}