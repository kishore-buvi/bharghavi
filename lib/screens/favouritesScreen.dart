import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widget/curvedBottomNavigationBar.dart';


class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> wishlistProducts = [];
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/getStarted', (route) => false);
      return;
    }

    try {
      final wishlistDoc = await _firestore.collection('wishlists').doc(user.uid).get();
      if (!wishlistDoc.exists) {
        setState(() {
          wishlistProducts = [];
          _isLoading = false;
        });
        return;
      }

      final wishlistData = wishlistDoc.data()!;
      final List products = wishlistData['items']['products'] ?? [];
      List<Map<String, dynamic>> tempProducts = [];
      for (var item in products) {
        final productDoc =
        await _firestore.collection('products').doc(item['productId']).get();
        if (productDoc.exists && productDoc.data()!['status']['isActive'] == true) {
          tempProducts.add({
            'id': productDoc.id,
            'name': productDoc.data()!['basicInfo']['name'] ?? 'Unnamed Product',
            'price': productDoc.data()!['pricing']['price']?.toDouble() ?? 0.0,
            'image': productDoc.data()!['media']['featuredImage'] ?? '',
            'quantity': productDoc.data()!['inventory']['quantity'] ?? 0,
          });
        }
      }
      setState(() {
        wishlistProducts = tempProducts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching wishlist: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load wishlist. Please try again.')),
      );
    }
  }

  Future<void> _removeFromWishlist(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final wishlistRef = _firestore.collection('wishlists').doc(user.uid);
      final wishlistDoc = await wishlistRef.get();
      if (wishlistDoc.exists) {
        List products = wishlistDoc.data()!['items']['products'] ?? [];
        products.removeWhere((item) => item['productId'] == productId);
        await wishlistRef.update({
          'items': {'products': products},
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _fetchWishlist();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed from wishlist')),
        );
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from wishlist')),
      );
    }
  }

  Future<void> _addToCart(String productId, Map<String, dynamic> product) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to add items to cart')),
      );
      Navigator.pushNamed(context, '/getStarted');
      return;
    }

    try {
      final cartRef = _firestore.collection('carts').doc(user.uid);
      final cartDoc = await cartRef.get();
      final cartData = cartDoc.exists ? cartDoc.data() : {'items': {'products': []}};

      List products = cartData?['items']['products'] ?? [];
      products.add({
        'productId': productId,
        'variantId': '',
        'quantity': 1,
        'price': product['price'],
        'addedAt': FieldValue.serverTimestamp(),
        'lastModified': FieldValue.serverTimestamp(),
      });

      await cartRef.set({
        'items': {'products': products},
        'totals': {
          'subtotal': FieldValue.increment(product['price']),
          'tax': 0,
          'shipping': 0,
          'total': FieldValue.increment(product['price']),
        },
        'createdAt':
        cartDoc.exists ? cartData!['createdAt'] : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product['name']} added to cart!')),
      );
    } catch (e) {
      print('Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart')),
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
          'Favorites',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Container(
        color: Color(0xFFE8F5E8),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : wishlistProducts.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Your wishlist is empty',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: wishlistProducts.length,
          itemBuilder: (context, index) {
            var product = wishlistProducts[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12)),
                      child: product['image'].isNotEmpty
                          ? Image.network(
                        product['image'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      )
                          : Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '₹${product['price'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _addToCart(product['id'], product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _removeFromWishlist(product['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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