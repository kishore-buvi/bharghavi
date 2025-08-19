import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isLoading = false;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  String _getProductId() {
    return widget.product['id'] ??
        widget.product['productId'] ??
        widget.product['_id'] ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';
  }
  void _navigateToCart() {
    Navigator.pushNamed(context, '/cart');
  }
  void _debugProductData() {
    print('=== Product Debug Info ===');
    print('Full product data: ${widget.product}');
    print('Product ID: ${widget.product['id']}');
    print('Product Name: ${_getProductName()}');
    print('Product Price: ${_getProductPrice()}');
    print('Current User ID: $_currentUserId');
    print('========================');
  }

  // Helper methods to extract product data
  String _getProductName() {
    return widget.product['basicInfo']?['name'] ??
        widget.product['name'] ??
        'Cold Pressed Virgin Groundnut oil';
  }

  String _getProductImage() {
    return widget.product['media']?['featuredImage'] ??
        widget.product['image'] ??
        'https://via.placeholder.com/200x200';
  }

  double _getProductPrice() {
    if (widget.product['pricing']?['price'] != null) {
      return (widget.product['pricing']['price'] as num).toDouble();
    } else if (widget.product['price'] != null) {
      return (widget.product['price'] as num).toDouble();
    }
    return 298.0;
  }

  double _getDiscountPercentage() {
    final discountRaw = widget.product['discount'];
    if (discountRaw is Map && discountRaw['percentage'] != null) {
      return (discountRaw['percentage'] as num).toDouble();
    } else if (discountRaw is num) {
      return discountRaw.toDouble();
    }
    return 10.0;
  }

  String _getProductSize() {
    return widget.product['basicInfo']?['size'] ??
        widget.product['size'] ??
        '1 litre';
  }

  double _getRating() {
    return widget.product['rating']?['average']?.toDouble() ?? 4.5;
  }

  Future<void> _addToCart() async {
    _debugProductData();
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
        'productId': widget.product['id'] ?? widget.product['productId'] ?? 'unknown',
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
    if (cartData['items'] != null && cartData['items']['products'] != null) {
      items = List.from(cartData['items']['products']);
    } else if (cartData['products'] != null) {
      items = List.from(cartData['products']);
    } else if (cartData['items'] != null) {
      items = List.from(cartData['items']);
    }

    final existingIndex = items.indexWhere(
            (item) => item['productId'] == widget.product['id']);

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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Calculate responsive dimensions based on screen size
    final isSmallScreen = screenWidth < 375;
    final isTablet = screenWidth > 600;

    // Design ratio calculations (based on your 402x630 design)
    final designWidth = 402.0;
    final designHeight = 630.0;

    // Scale factors
    final widthRatio = screenWidth / designWidth;
    final heightRatio = screenHeight / designHeight;
    final minRatio = widthRatio < heightRatio ? widthRatio : heightRatio;

    // Responsive dimensions
    final imageSize = (231 * minRatio).clamp(150.0, 280.0);
    final topSectionHeight = (244 * minRatio).clamp(200.0, 350.0);
    final bottomRadius = (50 * minRatio).clamp(25.0, 50.0);

    // Image overlay positioning
    final imageOverlapHeight = imageSize * 0.3; // Amount of image that overlaps bottom sheet

    final productName = _getProductName();
    final productPrice = _getProductPrice();
    final discountPercentage = _getDiscountPercentage();
    final productImage = _getProductImage();
    final productSize = _getProductSize();
    final rating = _getRating();

    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        color: const Color(0xFF4A7C59),
        child: SafeArea(
          child: Stack(
            children: [
              // Top section with green background
              Container(
                width: screenWidth,
                height: topSectionHeight - imageOverlapHeight,
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
                  ],
                ),
              ),

              // Bottom section with product details
              Positioned(
                top: topSectionHeight - imageOverlapHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(bottomRadius),
                      topRight: Radius.circular(bottomRadius),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 32 : (isSmallScreen ? 16 : 24),
                          imageOverlapHeight + (isSmallScreen ? 16 : 24),
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

                            // Rating
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A7C59),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: isSmallScreen ? 12 : 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 10 : 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rating',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // Price section
                            Row(
                              children: [
                                Text(
                                  '₹${productPrice.toInt()}',
                                  style: TextStyle(
                                    fontSize: isTablet ? 22 : (isSmallScreen ? 18 : 20),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 12),
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

                            // Features row
                            _buildFeaturesSection(isTablet, isSmallScreen),
                            SizedBox(height: isSmallScreen ? 16 : 24),

                            // Action buttons
                            _buildActionButtons(isTablet, isSmallScreen),
                            SizedBox(height: isSmallScreen ? 16 : 24),

                            // Product details expandable section with table format
                            _buildExpandableDetails(isTablet, isSmallScreen),

                            // Extra bottom padding
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Product image positioned to overlay the bottom sheet
              Positioned(
                top: topSectionHeight - imageOverlapHeight - (imageSize / 2),
                left: (screenWidth - imageSize) / 2,
                child: Container(
                  width: imageSize,
                  height: imageSize,
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
        // Add functionality for each feature button
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
        // Add to cart button
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
        // Buy now button
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              _showMessage('Proceeding to checkout...');
              // Add actual buy now functionality here
            },
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
    return Column(
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
            child: Table(
              columnWidths: {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: [
                _buildTableRow('Product Name:', 'Pure Cold Pressed Coconut Oil', isTablet, isSmallScreen, isFirst: true),
                _buildTableRow('Brand:', 'Bhargavi Oil Store', isTablet, isSmallScreen),
                _buildTableRow('Ingredients:', '100% Natural Coconut Oil', isTablet, isSmallScreen),
                _buildTableRow('Shelf life:', '24 months', isTablet, isSmallScreen),
                _buildTableRow('Packaging:', '1000ml - PET', isTablet, isSmallScreen),
                _buildTableRow('Usage:', 'For cooking', isTablet, isSmallScreen, isLast: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, bool isTablet, bool isSmallScreen, {bool isFirst = false, bool isLast = false}) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 12 : 16,
            horizontal: isSmallScreen ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
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
}