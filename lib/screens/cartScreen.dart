import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widget/curvedBottomNavigationBar.dart';


class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> cartItems = [];
  Map<String, dynamic>? cartData;
  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/getStarted', (route) => false);
      return;
    }

    try {
      final cartDoc = await _firestore.collection('carts').doc(user.uid).get();
      if (!cartDoc.exists) {
        setState(() {
          cartItems = [];

          _isLoading = false;
        });
        return;
      }

      final cartData = cartDoc.data()!;
      final List products = cartData['items']['products'] ?? [];
      List<Map<String, dynamic>> tempItems = [];
      for (var item in products) {
        final productDoc =
        await _firestore.collection('products').doc(item['productId']).get();
        if (productDoc.exists && productDoc.data()!['status']['isActive'] == true) {
          tempItems.add({
            'id': item['productId'],
            'name': productDoc.data()!['basicInfo']['name'] ?? 'Unnamed Product',
            'price': item['price']?.toDouble() ?? 0.0,
            'image': productDoc.data()!['media']['featuredImage'] ?? '',
            'quantity': item['quantity'] ?? 1,
          });
        }
      }
      setState(() {
        this.cartItems = tempItems;
        this.cartData = cartData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching cart: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cart. Please try again.')),
      );
    }
  }

  Future<void> _updateCartItemQuantity(String productId, int quantity) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (quantity < 1) {
      _removeFromCart(productId);
      return;
    }

    try {
      final cartRef = _firestore.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();
      if (cartDoc.exists) {
        List products = cartDoc.data()!['items']['products'] ?? [];
        final itemIndex = products.indexWhere((item) => item['productId'] == productId);
        if (itemIndex != -1) {
          final oldQuantity = products[itemIndex]['quantity'];
          final price = products[itemIndex]['price'];
          products[itemIndex]['quantity'] = quantity;
          products[itemIndex]['lastModified'] = FieldValue.serverTimestamp();
          final quantityDiff = quantity - oldQuantity;
          await cartRef.update({
            'items': {'products': products},
            'totals': {
              'subtotal': FieldValue.increment(quantityDiff * price),
              'tax': 0,
              'shipping': 0,
              'total': FieldValue.increment(quantityDiff * price),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _fetchCart();
        }
      }
    } catch (e) {
      print('Error updating cart item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cart')),
      );
    }
  }

  Future<void> _removeFromCart(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final cartRef = _firestore.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();
      if (cartDoc.exists) {
        List products = cartDoc.data()!['items']['products'] ?? [];
        final item = products.firstWhere((item) => item['productId'] == productId,
            orElse: () => null);
        if (item != null) {
          products.removeWhere((item) => item['productId'] == productId);
          await cartRef.update({
            'items': {'products': products},
            'totals': {
              'subtotal': FieldValue.increment(-(item['quantity'] * item['price'])),
              'tax': 0,
              'shipping': 0,
              'total': FieldValue.increment(-(item['quantity'] * item['price'])),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _fetchCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed from cart')),
          );
        }
      }
    } catch (e) {
      print('Error removing from cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from cart')),
      );
    }
  }

  Future<void> _placeOrder() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/getStarted', (route) => false);
      return;
    }

    try {
      final cartRef = _firestore.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();
      if (!cartDoc.exists || cartData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cart is empty')),
        );
        return;
      }

      final cartDataLocal = cartDoc.data()!;
      final List products = cartDataLocal['items']['products'] ?? [];
      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cart is empty')),
        );
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userDataLocal = userDoc.exists ? userDoc.data()! : {
        'personalInfo': {
          'firstName': '',
          'lastName': '',
        },
        'addresses': {
          'shipping': [{}],
          'billing': {},
        },
      };

      final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection('orders').doc(orderId).set({
      'customer': {
      'userId': user.uid,
      'email': user.email,
      'firstName': userDataLocal['personalInfo']['firstName'] ?? '',
      'lastName': userDataLocal['personalInfo']['lastName'] ?? '',
      },
      'orderInfo': {
      'orderNumber': orderId,
      'status': 'pending',
      'paymentStatus': 'pending',
      'fulfillmentStatus': 'unfulfilled',
      'currency': 'INR',
      'notes': '',
      },
      'items': {
      'products': products.map((item) async => {
      'productId': item['productId'],
      'variantId': item['variantId'],
      'name': (await _firestore
          .collection('products')
          .doc(item['productId'])
          .get())
          .data()?['basicInfo']['name'],
      'image': (await _firestore
          .collection('products')
          .doc(item['productId'])
          .get())
          .data()?['media']['featuredImage'],
      'price': item['price'],
      'quantity': item['quantity'],
      'sku': '',
      'total': item['price'] * item['quantity'],
      }).toList(),
      },
      'pricing': cartDataLocal['totals'],
      'addresses': {
      'shipping': userDataLocal['addresses']['shipping']?[0] ?? {},
      'billing': userDataLocal['addresses']['billing'] ?? {},
      },
      'shipping': {
      'method': '',
      'carrier': '',
      'trackingNumber': '',
      'estimatedDelivery': null,
      'actualDelivery': null,
      },
      'payment': {
      'method': '',
      'transactionId': '',
      'gateway': '',
      'gatewayResponse': {},
      },
      'timeline': {
      'events': [
      {
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'note': 'Order created',
      'updatedBy': user.uid,
      }
      ],
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      });

      await cartRef.delete();
      _fetchCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed successfully')),
      );
    } catch (e) {
      print('Error placing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order')),
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
          'Cart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () async {
                final user = _auth.currentUser;
                if (user == null) return;
                try {
                  await _firestore.collection('carts').doc(user.uid).delete();
                  _fetchCart();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cart cleared')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to clear cart')),
                  );
                }
              },
            ),
        ],
      ),
      body: Container(
        color: Color(0xFFE8F5E8),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : cartItems.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                child: Text('Continue Shopping'),
              ),
            ],
          ),
        )
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  var item = cartItems[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item['image'].isNotEmpty
                                ? Image.network(
                              item['image'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                  Icon(Icons.image, size: 50),
                            )
                                : Icon(Icons.image, size: 50),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove),
                                      onPressed: () => _updateCartItemQuantity(
                                          item['id'], item['quantity'] - 1),
                                    ),
                                    Text(
                                      '${item['quantity']}',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add),
                                      onPressed: () => _updateCartItemQuantity(
                                          item['id'], item['quantity'] + 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeFromCart(item['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₹${(cartData?['totals']['subtotal'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₹${(cartData?['totals']['tax'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shipping',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₹${(cartData?['totals']['shipping'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '₹${(cartData?['totals']['total'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Proceed to Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
}