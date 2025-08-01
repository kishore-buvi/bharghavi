import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic>? product;
  final bool isAdminMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddToCart;
  final Function(int)? onQuantityChanged;

  const ProductCard({
    Key? key,
    this.product,
    this.isAdminMode = false,
    required this.onEdit,
    required this.onDelete,
    required this.onAddToCart,
    this.onQuantityChanged,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isFavorited = false;
  bool _isLoading = false;
  StreamSubscription<User?>? _authSubscription;
  String? _currentUserId;
  int _cartQuantity = 0;

  @override
  void initState() {
    super.initState();
    _initializeUserBinding();
    _initializeCartQuantity();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initializeCartQuantity() {
    if (widget.product != null) {
      _cartQuantity = widget.product!['cartQuantity'] ??
          widget.product!['inventory']?['quantity'] ?? 1;
    }
  }

  void _initializeUserBinding() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUserId = user?.uid;
        });
        if (user != null) {
          _checkIfFavorited();
        } else {
          setState(() {
            _isFavorited = false;
          });
        }
      }
    });
  }

  Future<void> _checkIfFavorited() async {
    if (_currentUserId == null || widget.product == null) {
      setState(() => _isFavorited = false);
      return;
    }

    try {
      final wishlistRef = FirebaseFirestore.instance
          .collection('wishlists')
          .doc(_currentUserId);

      final wishlistDoc = await wishlistRef.get();

      if (wishlistDoc.exists && mounted) {
        final data = wishlistDoc.data() as Map<String, dynamic>;
        final products = data['items']?['products'] as List<dynamic>? ?? [];
        final isFavorited = products.any((item) =>
        item['productId'] == widget.product!['id']);

        setState(() => _isFavorited = isFavorited);
      }
    } catch (e) {
      print('Error checking favorite status: $e');
      if (mounted) {
        setState(() => _isFavorited = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      _showAuthRequiredMessage('sign in to add favorites');
      return;
    }

    if (widget.product == null) {
      _showMessage('Invalid product data', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wishlistRef = FirebaseFirestore.instance
          .collection('wishlists')
          .doc(_currentUserId);

      final newFavoriteState = !_isFavorited;
      setState(() => _isFavorited = newFavoriteState);

      if (newFavoriteState) {
        await _addToWishlist(wishlistRef);
        _showMessage('Added to favorites');
      } else {
        await _removeFromWishlist(wishlistRef);
        _showMessage('Removed from favorites');
      }
    } catch (e) {
      setState(() => _isFavorited = !_isFavorited);
      _showMessage('Error updating favorites: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addToWishlist(DocumentReference wishlistRef) async {
    // Use DateTime.now() instead of FieldValue.serverTimestamp()
    final now = DateTime.now();

    final productToAdd = {
      'productId': widget.product!['id'],
      'name': _getProductName(),
      'image': _getProductImage(),
      'price': _getProductPrice(),
      'isAvailable': true,
      'addedAt': now, // Use DateTime.now() instead of FieldValue.serverTimestamp()
      'userId': _currentUserId,
    };

    await wishlistRef.set({
      'userId': _currentUserId,
      'items': {
        'products': FieldValue.arrayUnion([productToAdd])
      },
      'createdAt': now, // Use DateTime.now() instead of FieldValue.serverTimestamp()
      'updatedAt': now, // Use DateTime.now() instead of FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
  }

  Future<void> _removeFromWishlist(DocumentReference wishlistRef) async {
    final wishlistDoc = await wishlistRef.get();
    if (wishlistDoc.exists) {
      final data = wishlistDoc.data() as Map<String, dynamic>;
      final products = List<dynamic>.from(data['items']?['products'] ?? []);

      final productToRemove = products.firstWhere(
            (item) => item['productId'] == widget.product!['id'],
        orElse: () => null,
      );

      if (productToRemove != null) {
        await wishlistRef.update({
          'items.products': FieldValue.arrayRemove([productToRemove]),
          'updatedAt': DateTime.now(), // Use DateTime.now() instead of FieldValue.serverTimestamp()
        });
      }
    }
  }
  Future<void> _addToCartAndNavigate(BuildContext context) async {
    if (_currentUserId == null) {
      _showAuthRequiredMessage('sign in to add items to cart');
      return;
    }

    if (widget.product == null) {
      _showMessage('No product selected to add to cart', isError: true);
      return;
    }

    try {
      _showLoadingDialog(context);
      await _addProductToCart();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        final productName = _getProductName();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName added to cart!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () => _navigateToCart(context),
            ),
          ),
        );

        // Auto-navigate to cart after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) _navigateToCart(context);
        });
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showMessage('Failed to add to cart: ${e.toString()}', isError: true);
      }
    }
  }

  // Replace these methods in your ProductCard class

  // Update your ProductCard's _addProductToCart method

// Replace these methods in your ProductCard class

  Future<void> _addProductToCart() async {
    if (widget.product == null || _currentUserId == null) {
      throw Exception('Invalid product or user data');
    }

    print('Adding product to cart: ${widget.product!['id']}'); // Debug log

    final cartRef = FirebaseFirestore.instance
        .collection('carts')
        .doc(_currentUserId);

    final cartDoc = await cartRef.get();
    final now = DateTime.now();

    final productData = {
      'productId': widget.product!['id'],
      'variantId': '',
      'quantity': _cartQuantity,
      'price': _getProductPrice(),
      'name': _getProductName(),
      'image': _getProductImage(),
      'sku': widget.product!['sku'] ?? '',
      'discount': _getDiscountPercentage(),
      'addedAt': now,
      'lastModified': now,
      'isAvailable': true,
      'userId': _currentUserId,
    };

    print('Product data to add: $productData'); // Debug log

    if (cartDoc.exists) {
      print('Cart exists, updating...'); // Debug log
      await _updateExistingCart(cartRef, cartDoc, productData);
    } else {
      print('Creating new cart...'); // Debug log
      await _createNewCart(cartRef, productData);
    }

    print('Product added to cart successfully'); // Debug log
  }

  Future<void> _updateExistingCart(DocumentReference cartRef,
      DocumentSnapshot cartDoc, Map<String, dynamic> productData) async {
    final now = DateTime.now(); // Define now in this method
    final cartData = cartDoc.data() as Map<String, dynamic>;

    // Handle different possible data structures
    List<dynamic> items = [];
    if (cartData['items'] != null && cartData['items']['products'] != null) {
      items = List.from(cartData['items']['products']);
    } else if (cartData['products'] != null) {
      items = List.from(cartData['products']);
    } else if (cartData['items'] != null) {
      items = List.from(cartData['items']);
    }

    print('Existing cart items: $items'); // Debug log

    final existingIndex = items.indexWhere(
            (item) => item['productId'] == widget.product!['id']);

    if (existingIndex != -1) {
      // Update existing item quantity
      items[existingIndex]['quantity'] =
          (items[existingIndex]['quantity'] ?? 0) + _cartQuantity;
      items[existingIndex]['lastModified'] = now;
      print('Updated existing item at index $existingIndex'); // Debug log
    } else {
      // Add new item
      items.add(productData);
      print('Added new item to cart'); // Debug log
    }

    final subtotal = _calculateSubtotal(items);

    // Use consistent structure
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

    print('Updating cart with data: $updateData'); // Debug log

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

    print('Creating new cart with data: $cartData'); // Debug log

    await cartRef.set(cartData);
  }

  double _calculateSubtotal(List<dynamic> items) {
    final subtotal = items.fold(0.0, (sum, item) =>
    sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)));
    print('Calculated subtotal: $subtotal for ${items.length} items'); // Debug log
    return subtotal;
  }
  void _updateQuantity(int delta) {
    final newQuantity = _cartQuantity + delta;
    final maxQuantity = widget.product!['inventory']?['quantity'] ?? 999;

    if (newQuantity >= 1 && newQuantity <= maxQuantity) {
      setState(() {
        _cartQuantity = newQuantity;
      });

      if (widget.onQuantityChanged != null) {
        widget.onQuantityChanged!(_cartQuantity);
      }
    }
  }

  // Helper methods to extract product data consistently
  String _getProductName() {
    return widget.product!['basicInfo']?['name'] ??
        widget.product!['name'] ??
        'Unknown Product';
  }

  String _getProductImage() {
    return widget.product!['media']?['featuredImage'] ??
        widget.product!['image'] ??
        'https://via.placeholder.com/151x116';
  }

  double _getProductPrice() {
    if (widget.product!['pricing']?['price'] != null) {
      return (widget.product!['pricing']['price'] as num).toDouble();
    } else if (widget.product!['price'] != null) {
      return (widget.product!['price'] as num).toDouble();
    } else if (widget.product!['selling_price'] != null) {
      return (widget.product!['selling_price'] as num).toDouble();
    }
    return 0.0;
  }

  double _getDiscountPercentage() {
    final discountRaw = widget.product!['discount'];
    if (discountRaw is Map && discountRaw['percentage'] != null) {
      return (discountRaw['percentage'] as num).toDouble();
    } else if (discountRaw is num) {
      return discountRaw.toDouble();
    }
    return 0.0;
  }

  String _getProductDescription() {
    return widget.product!['basicInfo']?['description'] ??
        widget.product!['description'] ??
        '';
  }

  bool _isProductInStock() {
    final inventory = widget.product!['inventory'];
    if (inventory != null) {
      final quantity = inventory['quantity'];
      return quantity == null || quantity > 0;
    }

    // Fallback to direct quantity field from ProductService
    final quantity = widget.product!['quantity'];
    return quantity == null || quantity > 0;
  }

  // UI Helper methods
  void _showAuthRequiredMessage(String action) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please $action'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _navigateToCart(BuildContext context) {
    Navigator.pushNamed(context, '/cart');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product == null) {
      return Container(
        width: 167,
        height: 187,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Center(child: Text('No product data')),
      );
    }

    final productName = _getProductName();
    final productDescription = _getProductDescription();
    final productPrice = _getProductPrice();
    final discountPercentage = _getDiscountPercentage();
    final productImage = _getProductImage();
    final isInStock = _isProductInStock();

    return Container(
      width: 167,
      height: 187,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Stack(
        children: [
          // Product Image
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Container(
              height: 116,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      productImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    if (!isInStock)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Favorite Button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _isLoading ? null : _toggleFavorite,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorited ? Colors.red : Colors.black54,
                  size: 14,
                ),
              ),
            ),
          ),

          // Discount Badge
          if (discountPercentage > 0)
            Positioned(
              right: 16,
              top: 100,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D632E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${discountPercentage.toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),

          // Product Name
          Positioned(
            left: 8,
            top: 132,
            right: 8,
            child: Text(
              productName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Product Description
          if (productDescription.isNotEmpty)
            Positioned(
              left: 8,
              top: 154,
              child: Text(
                productDescription,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Product Price
          Positioned(
            left: 8,
            bottom: widget.isAdminMode ? 35 : 50,
            child: Text(
              '₹${productPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Quantity Controls (for non-admin mode when quantity callback is provided)
          if (!widget.isAdminMode && widget.onQuantityChanged != null)
            Positioned(
              right: 8,
              bottom: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _updateQuantity(-1),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        child: const Icon(Icons.remove, size: 12, color: Colors.white),
                      ),
                    ),
                    Container(
                      width: 25,
                      height: 20,
                      color: Colors.white,
                      child: Center(
                        child: Text(
                          '$_cartQuantity',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _updateQuantity(1),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: const Icon(Icons.add, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action Buttons
          if (!widget.isAdminMode)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: !isInStock
                      ? Colors.grey[400]
                      : _currentUserId == null
                      ? Colors.grey[300]
                      : const Color(0xFFFFCF50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: !isInStock
                        ? null
                        : _currentUserId == null
                        ? null
                        : () {
                      // Use internal cart functionality first
                      _addToCartAndNavigate(context);
                      // Then call the provided callback if it exists
                      widget.onAddToCart();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Center(
                      child: Text(
                        !isInStock
                            ? 'Out of Stock'
                            : _currentUserId == null
                            ? 'Sign In Required'
                            : 'Add to Cart',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: !isInStock
                              ? Colors.white
                              : _currentUserId == null
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
          // Admin buttons
            Positioned(
              left: 8,
              bottom: 5,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: ElevatedButton(
                        onPressed: widget.onEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: ElevatedButton(
                        onPressed: widget.onDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}