import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductDetailScreen({
    Key? key,
    required this.productId,
    required this.productData,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int quantity = 1;
  bool isLoading = false;
  Map<String, dynamic>? fullProductData;
  bool isInWishlist = false;

  @override
  void initState() {
    super.initState();
    _loadFullProductDetails();
    _checkWishlistStatus();
  }

  Future<void> _loadFullProductDetails() async {
    try {
      final doc = await _firestore
          .collection('products')
          .doc(widget.productId)
          .get();

      if (doc.exists) {
        setState(() {
          fullProductData = doc.data();
        });
      }
    } catch (e) {
      print('Error loading product details: $e');
    }
  }

  Future<void> _checkWishlistStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final wishlistDoc = await _firestore
          .collection('wishlists')
          .doc(user.uid)
          .get();

      if (wishlistDoc.exists) {
        final wishlistData = wishlistDoc.data()!;
        final items = List<dynamic>.from(wishlistData['items'] ?? []);
        setState(() {
          isInWishlist = items.any((item) => item['productId'] == widget.productId);
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
    }
  }

  Future<void> _toggleWishlist() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please login to add to wishlist', Colors.orange);
      return;
    }

    try {
      final wishlistRef = _firestore.collection('wishlists').doc(user.uid);
      final wishlistDoc = await wishlistRef.get();

      Map<String, dynamic> productInfo = _getProductInfo();

      if (wishlistDoc.exists) {
        final wishlistData = wishlistDoc.data()!;
        List<dynamic> items = List<dynamic>.from(wishlistData['items'] ?? []);

        if (isInWishlist) {
          // Remove from wishlist
          items.removeWhere((item) => item['productId'] == widget.productId);
        } else {
          // Add to wishlist
          items.add({
            'productId': widget.productId,
            'name': productInfo['name'],
            'price': productInfo['price'],
            'image': productInfo['image'],
            'addedAt': FieldValue.serverTimestamp(),
          });
        }

        await wishlistRef.update({
          'items': items,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new wishlist
        await wishlistRef.set({
          'items': [{
            'productId': widget.productId,
            'name': productInfo['name'],
            'price': productInfo['price'],
            'image': productInfo['image'],
            'addedAt': FieldValue.serverTimestamp(),
          }],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        isInWishlist = !isInWishlist;
      });

      _showSnackBar(
        isInWishlist ? 'Added to wishlist' : 'Removed from wishlist',
        Colors.green,
      );
    } catch (e) {
      print('Error toggling wishlist: $e');
      _showSnackBar('Failed to update wishlist', Colors.red);
    }
  }

  Map<String, dynamic> _getProductInfo() {
    String name = '';
    double price = 0.0;
    String image = '';
    String description = '';
    String brand = '';
    String sku = '';

    if (fullProductData != null) {
      // Use full product data from Firestore
      name = fullProductData!['basicInfo']['name'] ?? widget.productData['name'] ?? '';
      price = fullProductData!['pricing']['price']?.toDouble() ?? widget.productData['price']?.toDouble() ?? 0.0;
      image = fullProductData!['media']['featuredImage'] ?? widget.productData['image'] ?? '';
      description = fullProductData!['basicInfo']['description'] ?? widget.productData['description'] ?? '';
      brand = fullProductData!['basicInfo']['brand'] ?? 'STANDARD OF SPICES';
      sku = fullProductData!['basicInfo']['sku'] ?? '';
    } else {
      // Fallback to widget.productData
      name = widget.productData['name'] ?? '';
      price = widget.productData['price']?.toDouble() ?? 0.0;
      image = widget.productData['image'] ?? '';
      description = widget.productData['description'] ?? '';
      brand = 'STANDARD OF SPICES';
      sku = '';
    }

    return {
      'name': name,
      'price': price,
      'image': image,
      'description': description,
      'brand': brand,
      'sku': sku,
    };
  }

  Future<void> _addToCart() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please login to add to cart', Colors.orange);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> productInfo = _getProductInfo();

      final cartRef = _firestore.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        // Update existing cart
        final cartData = cartDoc.data()!;
        List<dynamic> items = List<dynamic>.from(cartData['items']['products'] ?? []);

        // Check if product already exists in cart
        int existingIndex = items.indexWhere((item) =>
        item['productId'] == widget.productId);

        if (existingIndex != -1) {
          // Update quantity
          items[existingIndex]['quantity'] += quantity;
          items[existingIndex]['lastModified'] = FieldValue.serverTimestamp();
        } else {
          // Add new item
          items.add({
            'productId': widget.productId,
            'variantId': '',
            'quantity': quantity,
            'price': productInfo['price'],
            'name': productInfo['name'],
            'image': productInfo['image'],
            'sku': productInfo['sku'],
            'brand': productInfo['brand'],
            'addedAt': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
            'isAvailable': true,
          });
        }

        // Calculate totals
        double subtotal = items.fold(0.0, (sum, item) =>
        sum + (item['price'] * item['quantity']));

        await cartRef.update({
          'items.products': items,
          'totals.subtotal': subtotal,
          'totals.total': subtotal,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new cart
        await cartRef.set({
          'items': {
            'products': [{
              'productId': widget.productId,
              'variantId': '',
              'quantity': quantity,
              'price': productInfo['price'],
              'name': productInfo['name'],
              'image': productInfo['image'],
              'sku': productInfo['sku'],
              'brand': productInfo['brand'],
              'addedAt': FieldValue.serverTimestamp(),
              'lastModified': FieldValue.serverTimestamp(),
              'isAvailable': true,
            }],
          },
          'totals': {
            'subtotal': productInfo['price'] * quantity,
            'tax': 0,
            'shipping': 0,
            'discount': 0,
            'total': productInfo['price'] * quantity,
          },
          'appliedCoupons': [],
          'selectedShippingMethod': '',
          'estimatedTax': 0,
          'estimatedShipping': 0,
          'savedForLater': [],
          'abandonedAt': null,
          'recoveryEmailSent': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _showSnackBar('Added to cart successfully!', Colors.green);

        // Show dialog with cart options
        _showCartDialog();
      }
    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        _showSnackBar('Failed to add to cart. Please try again.', Colors.red);
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Added to Cart'),
          content: const Text('Product has been added to your cart successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Shopping'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/cart');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E5C3E),
                foregroundColor: Colors.white,
              ),
              child: const Text('View Cart'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> productInfo = _getProductInfo();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
          IconButton(
            icon: Icon(
              isInWishlist ? Icons.favorite : Icons.favorite_border,
              color: isInWishlist ? Colors.red : Colors.black,
            ),
            onPressed: _toggleWishlist,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with circular frame
            Container(
              height: 300,
              width: double.infinity,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2E5C3E),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ClipOval(
                          child: Image.network(
                            productInfo['image'].isNotEmpty
                                ? productInfo['image']
                                : 'https://via.placeholder.com/200',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.image, size: 60, color: Colors.grey[400]),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productInfo['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productInfo['description'].isNotEmpty
                        ? productInfo['description']
                        : 'Premium quality product from STANDARD OF SPICES',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${productInfo['price'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (fullProductData?['discount']['percentage'] != null &&
                          fullProductData!['discount']['percentage'] > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${fullProductData!['discount']['percentage'].toInt()}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Features Row
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FeatureItem(icon: Icons.local_shipping, label: 'Fast Delivery'),
                  _FeatureItem(icon: Icons.eco, label: '100% Natural'),
                  _FeatureItem(icon: Icons.verified_user, label: 'Quality Assurance'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quantity Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Quantity: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: quantity > 1 ? () {
                            setState(() {
                              quantity--;
                            });
                          } : null,
                          icon: const Icon(Icons.remove),
                          iconSize: 20,
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              quantity++;
                            });
                          },
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Product Details Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Brand',
                    value: productInfo['brand'],
                  ),
                  _DetailRow(
                    label: 'SKU',
                    value: productInfo['sku'].isNotEmpty ? productInfo['sku'] : 'N/A',
                  ),
                  _DetailRow(
                    label: 'Weight',
                    value: fullProductData?['specifications']['weight']?.toString() ?? '1 kg',
                  ),
                  const _DetailRow(
                    label: 'Type',
                    value: 'Organic Cold Pressed',
                  ),
                  const _DetailRow(
                    label: 'Country',
                    value: 'India',
                  ),
                  const _DetailRow(
                    label: 'Packaging',
                    value: 'Premium Quality',
                  ),
                  const _DetailRow(
                    label: 'Shelf Life',
                    value: '12 months',
                  ),
                  if (fullProductData?['inventory']['quantity'] != null)
                    _DetailRow(
                      label: 'Stock',
                      value: '${fullProductData!['inventory']['quantity']} units available',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add to Cart Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCF50),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                )
                    : const Text(
                  'ADD TO CART',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Buy Now Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _addToCart().then((_) {
                    Navigator.pushNamed(context, '/checkout');
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E5C3E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Buy now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2E5C3E),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}