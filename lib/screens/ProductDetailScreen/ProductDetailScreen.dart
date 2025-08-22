import 'package:bharghavi/razorPay/service/paymentService.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bharghavi/screens/profile/addressSelectionScreen.dart'; // Added import for AddressSelectionScreen

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin, PaymentMixin {
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isPaymentLoading = false;
  String? _currentUserId;
  int _cartQuantity = 1;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Debug product data on init
    _debugProductData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getProductId() {
    return widget.product['id'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _navigateToCart() {
    Navigator.pushNamed(context, '/cart');
  }

  void _debugProductData() {
    print('=== Product Debug Info ===');
    print('Full product data: ${widget.product}');
    print('Product ID: ${_getProductId()}');
    print('Product Name: ${_getProductName()}');
    print('Product Price: ${_getProductPrice()}');
    print('Product Image: ${_getProductImage()}');
    print('Discount Percentage: ${_getDiscountPercentage()}');
    print('Product Size: ${_getProductSize()}');
    print('Details: ${widget.product['details']}');
    print('Current User ID: $_currentUserId');
    print('====================');
  }

  void showPaymentSuccess(String paymentId) {
    _showMessage('Payment successful! Payment ID: $paymentId');
  }

  void showPaymentError(String error) {
    _showMessage('Payment failed: $error', isError: true);
  }

  Future<Map<String, dynamic>?> _getDefaultAddress() async {
    if (_currentUserId == null) return null;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> shippingAddresses = data['addresses']?['shipping'] ?? [];
        final defaultAddress = shippingAddresses.firstWhere(
              (addr) => addr['isDefault'] == true,
          orElse: () => null,
        );
        return defaultAddress;
      }
      return null;
    } catch (e) {
      print('Error fetching default address: $e');
      _showMessage('Error fetching address: $e', isError: true);
      return null;
    }
  }

  void _placeOrder() async {
    Map<String, dynamic>? selectedAddress = await _getDefaultAddress();

    if (selectedAddress == null) {
      // No default address found, prompt user to select or add one
      selectedAddress = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddressSelectionScreen(),
        ),
      );

      if (selectedAddress == null) {
        _showMessage('Please select a shipping address to proceed.', isError: true);
        return;
      }
    }

    final double price = _getProductPrice();
    final double subtotal = price * _cartQuantity;
    final double gst = subtotal * 0.18;
    final double discount = subtotal * (_getDiscountPercentage() / 100);
    final double deliveryFee = 60.0;
    final double total = (subtotal + gst + deliveryFee) - discount;

    print('=== Payment Debug Info ===');
    print('Product Price: $price');
    print('Cart Quantity: $_cartQuantity');
    print('Subtotal: $subtotal');
    print('GST: $gst');
    print('Discount: $discount');
    print('Delivery Fee: $deliveryFee');
    print('Final Total: $total');
    print('Selected Address: $selectedAddress');
    print('========================');

    if (total <= 0) {
      _showMessage('Invalid amount calculated. Please try again.', isError: true);
      return;
    }

    startPayment(
      amount: total,
      productName: _getProductName(),
      description: 'Purchase of ${_getProductName()}',
      onPaymentStart: () {
        setState(() {
          _isPaymentLoading = true;
        });
      },
      onPaymentSuccess: (paymentId) {
        _processPayment(paymentId, selectedAddress);
      },
      onPaymentError: (error) {
        showPaymentError(error);
      },
      onPaymentComplete: () {
        setState(() {
          _isPaymentLoading = false;
        });
      },
    );
  }

  Future<void> _processPayment(String paymentId, Map<String, dynamic>? shippingAddress) async {
    try {
      final double price = _getProductPrice();
      final double subtotal = price * _cartQuantity;
      final double gst = subtotal * 0.18;
      final double discount = subtotal * (_getDiscountPercentage() / 100);
      final double deliveryFee = 60.0;
      final double total = (subtotal + gst + deliveryFee) - discount;

      // Save order to Firestore with detailed structure
      await FirebaseFirestore.instance.collection('orders').add({
        'customer': {
          'userId': _currentUserId,
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
          'firstName': '',
          'lastName': '',
          'phone': '',
        },
        'orderInfo': {
          'orderNumber': 'ORD_${DateTime.now().millisecondsSinceEpoch}',
          'status': 'pending',
          'paymentStatus': 'paid',
          'fulfillmentStatus': 'unfulfilled',
          'currency': 'INR',
          'notes': '',
          'internalNotes': '',
          'priority': 'medium',
        },
        'items': {
          'products': [
            {
              'productId': _getProductId(),
              'variantId': '',
              'name': _getProductName(),
              'image': _getProductImage(),
              'price': price,
              'quantity': _cartQuantity,
              'sku': widget.product['sku'] ?? '',
              'weight': widget.product['details']?['weight'] ?? 0.0,
              'vendorId': widget.product['vendor']?['vendorId'] ?? '',
              'total': price * _cartQuantity,
            }
          ],
        },
        'pricing': {
          'subtotal': subtotal,
          'tax': gst,
          'shipping': deliveryFee,
          'discount': discount,
          'total': total,
          'breakdown': {
            'itemsTotal': subtotal,
            'shippingTotal': deliveryFee,
            'taxTotal': gst,
            'discountTotal': discount,
            'handlingFee': 0.0,
          },
        },
        'addresses': {
          'shipping': shippingAddress ?? {},
          'billing': shippingAddress ?? {},
        },
        'payment': {
          'method': 'razorpay',
          'transactionId': paymentId,
          'gateway': 'razorpay',
          'gatewayResponse': {},
          'installments': 1,
          'cardLastFour': '',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Order saved to Firestore successfully');
      _handlePaymentSuccess(paymentId);
    } catch (e) {
      print('Error saving order: $e');
      showPaymentError('Failed to save order: $e');
    }
  }

  // Helper methods to extract product data
  String _getProductName() {
    return widget.product['basicInfo']?['name'] ?? widget.product['name'] ?? 'Unnamed Product';
  }

  String _getProductImage() {
    return widget.product['media']?['featuredImage'] ?? widget.product['image'] ?? 'https://via.placeholder.com/200x200';
  }

  double _getProductPrice() {
    return (widget.product['pricing']?['price'] as num?)?.toDouble() ??
        (widget.product['price'] as num?)?.toDouble() ?? 0.0;
  }

  double _getDiscountPercentage() {
    final discountRaw = widget.product['discount'];
    if (discountRaw is Map && discountRaw['percentage'] != null) {
      return (discountRaw['percentage'] as num).toDouble();
    } else if (discountRaw is num) {
      return discountRaw.toDouble();
    }
    return 0.0;
  }

  String _getProductSize() {
    return widget.product['details']?['size'] ?? widget.product['size'] ?? 'Not specified';
  }

  Future<void> _addToCart() async {
    if (_currentUserId == null) {
      _showMessage('Please sign in to add items to cart', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('carts')
          .doc(_currentUserId);

      final cartDoc = await cartRef.get();
      final now = DateTime.now();

      final productData = {
        'productId': _getProductId(),
        'variantId': '',
        'quantity': _cartQuantity,
        'price': _getProductPrice(),
        'name': _getProductName(),
        'image': _getProductImage(),
        'sku': widget.product['sku'] ?? '',
        'discount': _getDiscountPercentage(),
        'addedAt': now,
        'lastModified': now,
        'isAvailable': true,
        'userId': _currentUserId,
      };

      if (cartDoc.exists) {
        await _updateExistingCart(cartRef, cartDoc, productData);
      } else {
        await _createNewCart(cartRef, productData);
      }

      _showMessage('${_getProductName()} added to cart!');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _navigateToCart();
        }
      });
    } catch (e) {
      _showMessage('Failed to add to cart: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateExistingCart(DocumentReference cartRef,
      DocumentSnapshot cartDoc, Map<String, dynamic> productData) async {
    final now = DateTime.now();
    final cartData = cartDoc.data() as Map<String, dynamic>;

    List<dynamic> items = [];
    if (cartData['items']?['products'] != null) {
      items = List.from(cartData['items']['products']);
    } else if (cartData['products'] != null) {
      items = List.from(cartData['products']);
    } else if (cartData['items'] != null) {
      items = List.from(cartData['items']);
    }

    final existingIndex = items.indexWhere(
            (item) => item['productId'] == _getProductId());

    if (existingIndex != -1) {
      items[existingIndex]['quantity'] =
          (items[existingIndex]['quantity'] ?? 0) + _cartQuantity;
      items[existingIndex]['lastModified'] = now;
    } else {
      items.add(productData);
    }

    final subtotal = _calculateSubtotal(items);

    final updateData = {
      'items': {
        'products': items
      },
      'totals': {
        'subtotal': subtotal,
        'total': subtotal
      },
      'updatedAt': now,
    };

    await cartRef.update(updateData);
  }

  Future<void> _createNewCart(DocumentReference cartRef,
      Map<String, dynamic> productData) async {
    final price = _getProductPrice() * _cartQuantity;
    final now = DateTime.now();

    final cartData = {
      'userId': _currentUserId,
      'items': {
        'products': [productData],
      },
      'totals': {
        'subtotal': price,
        'tax': 0,
        'shipping': 0,
        'discount': 0,
        'total': price
      },
      'createdAt': now,
      'updatedAt': now,
    };

    await cartRef.set(cartData);
  }

  double _calculateSubtotal(List<dynamic> items) {
    return items.fold(0.0, (sum, item) =>
    sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)));
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showBillSummary() {
    final double price = _getProductPrice();
    final double subtotal = price * _cartQuantity;
    final double gst = subtotal * 0.18;
    final double discount = subtotal * (_getDiscountPercentage() / 100);
    final double deliveryFee = 60.0;
    final double total = (subtotal + gst + deliveryFee) - discount;

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
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildBillRow('Item Total & GST', '₹${(subtotal + gst).toStringAsFixed(1)}'),
                    const SizedBox(height: 15),
                    _buildBillRow('Discount', '₹${discount.toStringAsFixed(1)}', isDiscount: true),
                    const SizedBox(height: 15),
                    _buildBillRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(1)}'),
                    const SizedBox(height: 15),
                    const Divider(),
                    _buildBillRow('Total Cost', '₹${total.toStringAsFixed(1)}', isTotal: true),
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
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isPaymentLoading ? null : () {
                          Navigator.pop(context);
                          _placeOrder();
                        },
                        child: _isPaymentLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                            : const Text(
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final isSmallScreen = screenWidth < 375;
    final isTablet = screenWidth > 600;

    final designWidth = 402.0;
    final designHeight = 630.0;

    final widthRatio = screenWidth / designWidth;
    final heightRatio = screenHeight / designHeight;
    final minRatio = widthRatio < heightRatio ? widthRatio : heightRatio;

    final imageSize = (231 * minRatio).clamp(150.0, 280.0);
    final topSectionHeight = (244 * minRatio).clamp(200.0, 350.0);
    final bottomRadius = (50 * minRatio).clamp(25.0, 50.0);

    final productName = _getProductName();
    final productPrice = _getProductPrice();
    final discountPercentage = _getDiscountPercentage();
    final productImage = _getProductImage();
    final productSize = _getProductSize();

    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        color: const Color(0xFF4A7C59),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with green background and image
              Container(
                width: screenWidth,
                height: topSectionHeight,
                color: const Color(0xFF4A7C59),
                child: Stack(
                  children: [
                    // Back button
                    Positioned(
                      top: 20,
                      left: 20,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: isSmallScreen ? 35 : 40,
                          height: isSmallScreen ? 35 : 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: isSmallScreen ? 18 : 20,
                          ),
                        ),
                      ),
                    ),
                    // Centered product image
                    Center(
                      child: Container(
                        width: imageSize,
                        height: imageSize,
                        margin: EdgeInsets.only(top: 20.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            productImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.image,
                                size: imageSize * 0.4,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom section with product details
              Expanded(
                child: Container(
                  width: screenWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(bottomRadius),
                      topRight: Radius.circular(bottomRadius),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : (isSmallScreen ? 16 : 24),
                      20.0,
                      isTablet ? 32 : (isSmallScreen ? 16 : 24),
                      isTablet ? 32 : (isSmallScreen ? 16 : 24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name and size
                        Text(
                          productName,
                          style: TextStyle(
                            fontSize: isTablet ? 28 : (isSmallScreen ? 20 : 24),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 8),
                        Text(
                          productSize,
                          style: TextStyle(
                            fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),

                        // Price section
                        Row(
                          children: [
                            if (discountPercentage > 0)
                              Text(
                                '₹${(productPrice / (1 - discountPercentage / 100)).toInt()}',
                                style: TextStyle(
                                  fontSize: isTablet ? 22 : (isSmallScreen ? 18 : 20),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            if (discountPercentage > 0) const SizedBox(width: 12),
                            Text(
                              '₹${productPrice.toInt()}',
                              style: TextStyle(
                                fontSize: isTablet ? 22 : (isSmallScreen ? 18 : 20),
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (discountPercentage > 0) const SizedBox(width: 12),
                            if (discountPercentage > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 6 : 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A7C59),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${discountPercentage.toInt()}% Offer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 24),

                        // Quantity selector
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_cartQuantity > 1) {
                                  setState(() => _cartQuantity--);
                                }
                              },
                              child: Container(
                                width: isSmallScreen ? 30 : 40,
                                height: isSmallScreen ? 30 : 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: isSmallScreen ? 16 : 20,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_cartQuantity',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _cartQuantity++);
                              },
                              child: Container(
                                width: isSmallScreen ? 30 : 40,
                                height: isSmallScreen ? 30 : 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: isSmallScreen ? 16 : 20,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 24),

                        // Features row
                        _buildFeaturesSection(isTablet, isSmallScreen),
                        SizedBox(height: isSmallScreen ? 16 : 24),

                        // Action buttons
                        _buildActionButtons(isTablet, isSmallScreen),
                        SizedBox(height: isSmallScreen ? 16 : 24),

                        // Product details expandable section
                        _buildExpandableDetails(isTablet, isSmallScreen),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(bool isTablet, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: _buildFeatureItem(Icons.local_shipping_outlined, 'Fast\ndelivery', isTablet, isSmallScreen)),
        Expanded(child: _buildFeatureItem(Icons.eco_outlined, '100%\nNatural', isTablet, isSmallScreen)),
        Expanded(child: _buildFeatureItem(Icons.verified_user_outlined, 'Quality\nAssurance', isTablet, isSmallScreen)),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool isTablet, bool isSmallScreen) {
    final iconSize = isTablet ? 60.0 : (isSmallScreen ? 40.0 : 50.0);
    final iconInnerSize = isTablet ? 28.0 : (isSmallScreen ? 20.0 : 24.0);

    return GestureDetector(
      onTap: () {
        if (icon == Icons.local_shipping_outlined) {
          _showMessage('Fast delivery: Get your order within 24 hours!');
        } else if (icon == Icons.eco_outlined) {
          _showMessage('100% Natural: No artificial additives or preservatives');
        } else if (icon == Icons.verified_user_outlined) {
          _showMessage('Quality Assurance: Premium quality guaranteed');
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: iconInnerSize,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 14 : (isSmallScreen ? 10 : 12),
              color: Colors.grey[700],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isTablet, bool isSmallScreen) {
    final buttonHeight = isTablet ? 56.0 : (isSmallScreen ? 44.0 : 50.0);
    final fontSize = isTablet ? 18.0 : (isSmallScreen ? 14.0 : 16.0);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _addToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCF50),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
            ),
            child: _isLoading
                ? SizedBox(
              width: isSmallScreen ? 16 : 20,
              height: isSmallScreen ? 16 : 20,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            )
                : Text(
              'ADD TO CART',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: _showBillSummary,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
            ),
            child: Text(
              'Buy now',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableDetails(bool isTablet, bool isSmallScreen) {
    final description = widget.product['basicInfo']?['description'] ?? widget.product['description'] ?? 'No description available';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product details',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: isTablet ? 28 : 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1.0,
          child: Container(
            margin: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(2.5),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(color: Colors.grey[300]!, width: 0.5),
                    verticalInside: BorderSide.none,
                  ),
                  children: [
                    _buildTableRow('Product Name:', _getProductName(), isTablet, isSmallScreen, isFirst: true),
                    _buildTableRow('Description:', description, isTablet, isSmallScreen),
                    _buildTableRow('Brand:', widget.product['details']?['brand'] ?? 'Not specified', isTablet, isSmallScreen),
                    _buildTableRow('Ingredients:', widget.product['details']?['ingredients'] ?? 'Not specified', isTablet, isSmallScreen),
                    _buildTableRow('Shelf Life:', widget.product['details']?['shelfLife'] ?? 'Not specified', isTablet, isSmallScreen),
                    _buildTableRow('Packaging:', widget.product['details']?['packaging'] ?? 'Not specified', isTablet, isSmallScreen),
                    _buildTableRow('Usage:', widget.product['details']?['type'] ?? 'Not specified', isTablet, isSmallScreen, isLast: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, bool isTablet, bool isSmallScreen,
      {bool isFirst = false, bool isLast = false}) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          top: isFirst ? BorderSide.none : BorderSide(color: Colors.grey[300]!, width: 0.5),
          bottom: isLast ? BorderSide.none : BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 12 : 16,
            horizontal: isSmallScreen ? 12 : 16,
          ),
          color: Colors.grey[50],
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : (isSmallScreen ? 12 : 14),
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 12 : 16,
            horizontal: isSmallScreen ? 12 : 16,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 16 : (isSmallScreen ? 12 : 14),
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _handlePaymentSuccess(String paymentId) {
    showPaymentSuccess(paymentId);

    // Navigate to order success screen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/order-success', arguments: paymentId);
      }
    });
  }
}