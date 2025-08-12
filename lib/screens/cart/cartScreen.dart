import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> cartItems = [];
  double _cartTotal = 0.0;
  double _discount = 0.0;
  double _deliveryFee = 60.0;
  double _gst = 0.0;
  StreamSubscription<DocumentSnapshot>? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCartChanges(); // Use real-time listener

    // Backup: Also refresh when widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchCartData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart data when screen becomes active
    _fetchCartData();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    super.dispose();
  }

  // Real-time listener for cart changes
  void _listenToCartChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _cartSubscription = FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          if (snapshot.exists && snapshot.data() != null) {
            final cartData = snapshot.data() as Map<String, dynamic>;
            final items = cartData['items']?['products'] as List<dynamic>? ?? [];

            setState(() {
              cartItems = items.map((item) => Map<String, dynamic>.from(item)).toList();
              _cartTotal = _calculateSubtotal();
              _gst = _cartTotal * 0.18;
              _discount = _cartTotal * 0.10;
              _isLoading = false;
            });
          } else {
            setState(() {
              cartItems = [];
              _cartTotal = 0.0;
              _gst = 0.0;
              _discount = 0.0;
              _isLoading = false;
            });
          }
        }
      }, onError: (error) {
        print('Error listening to cart changes: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } else {
      // No user signed in
      setState(() {
        cartItems = [];
        _cartTotal = 0.0;
        _gst = 0.0;
        _discount = 0.0;
        _isLoading = false;
      });
    }
  }

  // Manual refresh method (backup)
  Future<void> _fetchCartData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _fetchCartItems(user.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cart: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchCartItems(String userId) async {
    try {
      final cartDoc = await FirebaseFirestore.instance
          .collection('carts')
          .doc(userId)
          .get();

      if (cartDoc.exists && cartDoc.data() != null) {
        final cartData = cartDoc.data()!;
        final items = cartData['items']?['products'] as List<dynamic>? ?? [];

        cartItems = items.map((item) => Map<String, dynamic>.from(item)).toList();

        // Calculate totals
        _cartTotal = _calculateSubtotal();
        _gst = _cartTotal * 0.18; // 18% GST
        _discount = _cartTotal * 0.10; // 10% discount as shown in UI
      } else {
        cartItems = [];
        _cartTotal = 0.0;
        _gst = 0.0;
        _discount = 0.0;
      }
    } catch (e) {
      print('Error fetching cart items: $e');
      cartItems = [];
      _cartTotal = 0.0;
    }
  }

  double _calculateSubtotal() {
    return cartItems.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0).toDouble();
      final quantity = item['quantity'] ?? 1;
      return sum + (price * quantity);
    });
  }

  double _calculateFinalTotal() {
    return (_cartTotal + _gst + _deliveryFee) - _discount;
  }

  // Manual refresh method for pull-to-refresh or refresh button
  void _onRefresh() {
    _fetchCartData();
  }

  Future<void> _updateQuantity(int index, int delta) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final item = cartItems[index];
    final oldQuantity = item['quantity'] ?? 1;
    final newQuantity = oldQuantity + delta;

    if (newQuantity < 1) {
      await _removeFromCart(index);
      return;
    }

    // Optimistic UI update
    setState(() {
      cartItems[index]['quantity'] = newQuantity;
      _cartTotal = _calculateSubtotal();
      _gst = _cartTotal * 0.18;
      _discount = _cartTotal * 0.10;
    });

    try {
      final cartRef = FirebaseFirestore.instance.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data()!;
        final items = List<Map<String, dynamic>>.from(cartData['items']?['products'] ?? []);

        if (index < items.length) {
          items[index]['quantity'] = newQuantity;
          items[index]['lastModified'] = DateTime.now();

          final newSubtotal = items.fold(0.0, (sum, item) =>
          sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)));

          await cartRef.update({
            'items.products': items,
            'totals.subtotal': newSubtotal,
            'totals.total': newSubtotal,
            'updatedAt': DateTime.now(),
          });
        }
      }
    } catch (e) {
      // Rollback optimistic update if needed
      setState(() {
        cartItems[index]['quantity'] = oldQuantity;
        _cartTotal = _calculateSubtotal();
        _gst = _cartTotal * 0.18;
        _discount = _cartTotal * 0.10;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating quantity: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFromCart(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final removedItem = cartItems[index];

    // Optimistically update UI
    setState(() {
      cartItems.removeAt(index);
      _cartTotal = _calculateSubtotal();
      _gst = _cartTotal * 0.18;
      _discount = _cartTotal * 0.10;
    });

    try {
      final cartRef = FirebaseFirestore.instance.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data()!;
        final items = List<Map<String, dynamic>>.from(cartData['items']?['products'] ?? []);

        if (index < items.length) {
          items.removeAt(index);

          final newSubtotal = items.fold(0.0, (sum, item) =>
          sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)));

          await cartRef.update({
            'items.products': items,
            'totals.subtotal': newSubtotal,
            'totals.total': newSubtotal,
            'updatedAt': DateTime.now(),
          });
        }

        // Final UI sync (important if all items removed)
        if (mounted) {
          setState(() {
            _cartTotal = _calculateSubtotal();
            _gst = _cartTotal * 0.18;
            _discount = _cartTotal * 0.10;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item removed from cart'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Rollback if failed
      setState(() {
        cartItems.insert(index, removedItem);
        _cartTotal = _calculateSubtotal();
        _gst = _cartTotal * 0.18;
        _discount = _cartTotal * 0.10;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBillSummary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bill Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Bill details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildBillRow('Item Total & GST', '₹${(_cartTotal + _gst).toStringAsFixed(1)}'),
                    const SizedBox(height: 15),
                    _buildBillRow('Discount', '10%', isDiscount: true),
                    const SizedBox(height: 15),
                    _buildBillRow('Delivery Fee', '₹${_deliveryFee.toStringAsFixed(1)}'),
                    const SizedBox(height: 15),
                    const Divider(),
                    _buildBillRow('Total Cost', '₹${_calculateFinalTotal().toStringAsFixed(1)}',
                        isTotal: true),

                    const SizedBox(height: 30),

                    const Text(
                      'By placing an order you agree to our',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Text(
                      'Terms And Conditions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Place Order Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _placeOrder();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _placeOrder() {
    // Implement order placement logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order placed successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _onRefresh,
            tooltip: 'Refresh Cart',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchCartData();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
          children: [
            // Cart Items List
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F8F0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: cartItems.isEmpty
                    ? _buildEmptyCart()
                    : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Product Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    item['image'] ?? 'https://via.placeholder.com/60x60',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                  ),
                                ),

                                const SizedBox(width: 15),

                                // Product Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Unknown Product',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Quantity Controls
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _updateQuantity(index, -1),
                                            child: Container(
                                              width: 25,
                                              height: 25,
                                              decoration: BoxDecoration(
                                                color: Colors.red[100],
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 15,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),

                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 10),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 15, vertical: 5),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              '${item['quantity'] ?? 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          GestureDetector(
                                            onTap: () => _updateQuantity(index, 1),
                                            child: Container(
                                              width: 25,
                                              height: 25,
                                              decoration: BoxDecoration(
                                                color: Colors.green[100],
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 15,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Price
                                Text(
                                  '₹${item['price']?.toString() ?? '0'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Missing Item Section (if needed)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Missing item',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/products');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '+ Add More Items',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Generate Bill Button
            if (cartItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F8F0),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _showBillSummary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Generate Bill',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/products'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }
}