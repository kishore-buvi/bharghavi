import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isAdminMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddToCart;

  const ProductCard({
    Key? key,
    required this.product,
    this.isAdminMode = false,
    required this.onEdit,
    required this.onDelete,
    required this.onAddToCart,
  }) : super(key: key);

  Future<void> _addToCartAndNavigate(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Add to cart logic
      await _addProductToCart(context);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message and navigate to cart
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['name'] ?? 'Product'} added to cart!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => _navigateToCart(context),
          ),
        ),
      );

      // Auto navigate to cart after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          _navigateToCart(context);
        }
      });

    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addProductToCart(BuildContext context) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    String userId = "current_user_id"; // Replace with actual user ID from auth

    final cartRef = firestore.collection('carts').doc(userId);
    final cartDoc = await cartRef.get();

    // Determine the price and discount from the product data structure
    double price = 0.0;
    double discount = 0.0;
    String productName = '';
    String productImage = '';

    // Handle different product data structures
    if (product.containsKey('pricing')) {
      // From Firestore structure
      price = product['pricing']['price']?.toDouble() ?? 0.0;
      discount = product['discount']['percentage']?.toDouble() ?? 0.0;
      productName = product['basicInfo']['name'] ?? 'Unknown Product';
      productImage = product['media']['featuredImage'] ?? '';
    } else {
      // From simplified structure
      price = (product['price'] is String)
          ? double.tryParse(product['price']) ?? 0.0
          : product['price']?.toDouble() ?? 0.0;
      discount = (product['discount'] is String)
          ? double.tryParse(product['discount']) ?? 0.0
          : product['discount']?.toDouble() ?? 0.0;
      productName = product['name'] ?? 'Unknown Product';
      productImage = product['image'] ?? '';
    }

    if (cartDoc.exists) {
      // Update existing cart
      final cartData = cartDoc.data()!;
      List<dynamic> items = cartData['items']['products'] ?? [];

      // Check if product already exists in cart
      int existingIndex = items.indexWhere((item) =>
      item['productId'] == (product['id'] ?? product['productId']));

      if (existingIndex != -1) {
        // Update quantity
        items[existingIndex]['quantity'] += 1;
        items[existingIndex]['lastModified'] = FieldValue.serverTimestamp();
      } else {
        // Add new item
        items.add({
          'productId': product['id'] ?? product['productId'] ?? '',
          'variantId': '',
          'quantity': 1,
          'price': price,
          'name': productName,
          'image': productImage,
          'sku': product['sku'] ?? '',
          'discount': discount,
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
            'productId': product['id'] ?? product['productId'] ?? '',
            'variantId': '',
            'quantity': 1,
            'price': price,
            'name': productName,
            'image': productImage,
            'sku': product['sku'] ?? '',
            'discount': discount,
            'addedAt': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
            'isAvailable': true,
          }],
        },
        'totals': {
          'subtotal': price,
          'tax': 0,
          'shipping': 0,
          'discount': 0,
          'total': price,
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
  }

  void _navigateToCart(BuildContext context) {
    Navigator.pushNamed(context, '/cart');
  }

  @override
  Widget build(BuildContext context) {
    // Extract product data safely
    String productName = '';
    String productDescription = '';
    String productPrice = '';
    double discountPercentage = 0.0;
    String productImage = '';

    // Handle different product data structures
    if (product.containsKey('basicInfo')) {
      // Firestore structure
      productName = product['basicInfo']['name'] ?? 'Product Name';
      productDescription = product['basicInfo']['description'] ?? '';
      productPrice = product['pricing']['price']?.toString() ?? '0';
      discountPercentage = product['discount']['percentage']?.toDouble() ?? 0.0;
      productImage = product['media']['featuredImage'] ?? 'https://via.placeholder.com/151x116';
    } else {
      // Simplified structure
      productName = product['name'] ?? 'Product Name';
      productDescription = product['description'] ?? '';
      productPrice = product['price']?.toString() ?? '0';
      discountPercentage = (product['discount'] is String)
          ? double.tryParse(product['discount']) ?? 0.0
          : product['discount']?.toDouble() ?? 0.0;
      productImage = product['image'] ?? 'https://via.placeholder.com/151x116';
    }

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
          ),
        ],
      ),
      child: Stack(
        children: [
          // Product image - full width with padding
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
                child: Image.network(
                  productImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  ),
                ),
              ),
            ),
          ),

          // Favorite icon - top right corner
          Positioned(
            top: 16,
            right: 16,
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
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_border,
                color: Colors.black54,
                size: 14,
              ),
            ),
          ),

          // Discount badge - bottom right of image
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

          // Product name - left aligned
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

          // Description - left aligned
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
              ),
            ),

          // Price - left aligned
          Positioned(
            left: 8,
            bottom: 28,
            child: Text(
              '₹$productPrice',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Add to Cart or Admin Buttons
          if (!isAdminMode)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCF50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _addToCartAndNavigate(context),
                    borderRadius: BorderRadius.circular(4),
                    child: const Center(
                      child: Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              left: 8,
              bottom: 5,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 20,
                      child: ElevatedButton(
                        onPressed: onEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Edit', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 20,
                      child: ElevatedButton(
                        onPressed: onDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Delete', style: TextStyle(fontSize: 10)),
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