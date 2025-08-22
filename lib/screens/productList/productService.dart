import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> fetchProducts(String categoryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('categorization.category', isEqualTo: categoryId)
          .where('status.isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'basicInfo': data['basicInfo'] ?? {
            'name': data['name'] ?? 'Unknown Product',
            'description': data['description'] ?? '',
          },
          'pricing': data['pricing'] ?? {
            'price': data['price'] ?? 0.0,
          },
          'media': data['media'] ?? {
            'featuredImage': data['image'] ?? '',
          },
          'categorization': data['categorization'] ?? {
            'category': categoryId,
          },
          'inventory': data['inventory'] ?? {
            'quantity': data['quantity'] ?? 0,
            'trackQuantity': true,
          },
          'discount': data['discount'] ?? {
            'percentage': data['discount'] ?? 0.0,
          },
          'details': data['details'] ?? {
            'brand': '',
            'type': '',
            'ingredients': '',
            'size': '',
            'packaging': '',
            'shelfLife': '',
          },
          'status': data['status'] ?? {
            'isActive': true,
          },
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],

          // Legacy fields for backward compatibility
          'name': data['basicInfo']?['name'] ?? data['name'] ?? 'Unknown Product',
          'price': data['pricing']?['price'] ?? data['price'] ?? 0.0,
          'image': data['media']?['featuredImage'] ?? data['image'] ?? '',
          'description': data['basicInfo']?['description'] ?? data['description'] ?? '',
          'quantity': data['inventory']?['quantity'] ?? data['quantity'] ?? 0,
          'discount': data['discount']?['percentage'] ?? data['discount'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchProductById(String productId) async {
    try {
      final docSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      final data = docSnapshot.data()!;
      return {
        'id': docSnapshot.id,
        'basicInfo': data['basicInfo'] ?? {
          'name': data['name'] ?? 'Unknown Product',
          'description': data['description'] ?? '',
        },
        'pricing': data['pricing'] ?? {
          'price': data['price'] ?? 0.0,
        },
        'media': data['media'] ?? {
          'featuredImage': data['image'] ?? '',
        },
        'categorization': data['categorization'] ?? {},
        'inventory': data['inventory'] ?? {
          'quantity': data['quantity'] ?? 0,
          'trackQuantity': true,
        },
        'discount': data['discount'] ?? {
          'percentage': data['discount'] ?? 0.0,
        },
        'details': data['details'] ?? {
          'brand': '',
          'type': '',
          'ingredients': '',
          'size': '',
          'packaging': '',
          'shelfLife': '',
        },
        'status': data['status'] ?? {
          'isActive': true,
        },
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],

        // Legacy fields for backward compatibility
        'name': data['basicInfo']?['name'] ?? data['name'] ?? 'Unknown Product',
        'price': data['pricing']?['price'] ?? data['price'] ?? 0.0,
        'image': data['media']?['featuredImage'] ?? data['image'] ?? '',
        'description': data['basicInfo']?['description'] ?? data['description'] ?? '',
        'quantity': data['inventory']?['quantity'] ?? data['quantity'] ?? 0,
        'discount': data['discount']?['percentage'] ?? data['discount'] ?? 0.0,
      };
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('status.isActive', isEqualTo: true)
          .get();

      final products = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'basicInfo': data['basicInfo'] ?? {
            'name': data['name'] ?? 'Unknown Product',
            'description': data['description'] ?? '',
          },
          'pricing': data['pricing'] ?? {
            'price': data['price'] ?? 0.0,
          },
          'media': data['media'] ?? {
            'featuredImage': data['image'] ?? '',
          },
          'categorization': data['categorization'] ?? {},
          'inventory': data['inventory'] ?? {
            'quantity': data['quantity'] ?? 0,
            'trackQuantity': true,
          },
          'discount': data['discount'] ?? {
            'percentage': data['discount'] ?? 0.0,
          },
          'details': data['details'] ?? {
            'brand': '',
            'type': '',
            'ingredients': '',
            'size': '',
            'packaging': '',
            'shelfLife': '',
          },
          'status': data['status'] ?? {
            'isActive': true,
          },
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],

          // Legacy fields for backward compatibility
          'name': data['basicInfo']?['name'] ?? data['name'] ?? 'Unknown Product',
          'price': data['pricing']?['price'] ?? data['price'] ?? 0.0,
          'image': data['media']?['featuredImage'] ?? data['image'] ?? '',
          'description': data['basicInfo']?['description'] ?? data['description'] ?? '',
          'quantity': data['inventory']?['quantity'] ?? data['quantity'] ?? 0,
          'discount': data['discount']?['percentage'] ?? data['discount'] ?? 0.0,
        };
      }).toList();

      // Filter products that match the search query
      return products.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final description = product['description']?.toString().toLowerCase() ?? '';
        final brand = product['details']?['brand']?.toString().toLowerCase() ?? '';
        final searchTerm = query.toLowerCase();

        return name.contains(searchTerm) ||
            description.contains(searchTerm) ||
            brand.contains(searchTerm);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  Future<String> addProduct(String categoryId, Map<String, dynamic> productData, File? imageFile) async {
    try {
      if (imageFile != null) {
        // Upload image first, then add URL to productData
        final imageUrl = await uploadImage('temp_${DateTime.now().millisecondsSinceEpoch}', imageFile);
        productData['media'] = {'featuredImage': imageUrl};
      }

      productData['categorization'] = {'category': categoryId};

      final docRef = await _firestore.collection('products').add({
        ...productData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update image path with actual product ID if image was uploaded
      if (imageFile != null) {
        final actualImageUrl = await uploadImage(docRef.id, imageFile);
        await docRef.update({'media.featuredImage': actualImageUrl});
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> updates, File? imageFile) async {
    try {
      if (imageFile != null) {
        final imageUrl = await uploadImage(productId, imageFile);
        updates['media'] = {'featuredImage': imageUrl};
      }

      await _firestore.collection('products').doc(productId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> updateProductStatus(String productId, bool isActive) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'status.isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update product status: $e');
    }
  }

  Future<void> updateInventory(String productId, int quantity) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'inventory.quantity': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update inventory: $e');
    }
  }

  Future<String> uploadImage(String productId, File imageFile) async {
    try {
      final ref = _storage.ref().child('products/$productId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
  Future<List<Map<String, dynamic>>> fetchCarouselImages() async {
    try {
      final querySnapshot = await _firestore.collection('carouselImages').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'imageUrl': data['imageUrl'] ?? data['image'] ?? '',
        };
      }).where((image) => image['imageUrl'].toString().isNotEmpty).toList();
    } catch (e) {
      throw Exception('Failed to fetch carousel images: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final querySnapshot = await _firestore.collection('categories').get();
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFeaturedProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('status.isActive', isEqualTo: true)
          .where('status.isFeatured', isEqualTo: true)
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'basicInfo': data['basicInfo'] ?? {
            'name': data['name'] ?? 'Unknown Product',
            'description': data['description'] ?? '',
          },
          'pricing': data['pricing'] ?? {
            'price': data['price'] ?? 0.0,
          },
          'media': data['media'] ?? {
            'featuredImage': data['image'] ?? '',
          },
          'categorization': data['categorization'] ?? {},
          'inventory': data['inventory'] ?? {
            'quantity': data['quantity'] ?? 0,
            'trackQuantity': true,
          },
          'discount': data['discount'] ?? {
            'percentage': data['discount'] ?? 0.0,
          },
          'details': data['details'] ?? {
            'brand': '',
            'type': '',
            'ingredients': '',
            'size': '',
            'packaging': '',
            'shelfLife': '',
          },
          'status': data['status'] ?? {
            'isActive': true,
          },
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],

          // Legacy fields for backward compatibility
          'name': data['basicInfo']?['name'] ?? data['name'] ?? 'Unknown Product',
          'price': data['pricing']?['price'] ?? data['price'] ?? 0.0,
          'image': data['media']?['featuredImage'] ?? data['image'] ?? '',
          'description': data['basicInfo']?['description'] ?? data['description'] ?? '',
          'quantity': data['inventory']?['quantity'] ?? data['quantity'] ?? 0,
          'discount': data['discount']?['percentage'] ?? data['discount'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch featured products: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProductsByPriceRange(double minPrice, double maxPrice) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('status.isActive', isEqualTo: true)
          .where('pricing.price', isGreaterThanOrEqualTo: minPrice)
          .where('pricing.price', isLessThanOrEqualTo: maxPrice)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'basicInfo': data['basicInfo'] ?? {
            'name': data['name'] ?? 'Unknown Product',
            'description': data['description'] ?? '',
          },
          'pricing': data['pricing'] ?? {
            'price': data['price'] ?? 0.0,
          },
          'media': data['media'] ?? {
            'featuredImage': data['image'] ?? '',
          },
          'categorization': data['categorization'] ?? {},
          'inventory': data['inventory'] ?? {
            'quantity': data['quantity'] ?? 0,
            'trackQuantity': true,
          },
          'discount': data['discount'] ?? {
            'percentage': data['discount'] ?? 0.0,
          },
          'details': data['details'] ?? {
            'brand': '',
            'type': '',
            'ingredients': '',
            'size': '',
            'packaging': '',
            'shelfLife': '',
          },
          'status': data['status'] ?? {
            'isActive': true,
          },
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],

          // Legacy fields for backward compatibility
          'name': data['basicInfo']?['name'] ?? data['name'] ?? 'Unknown Product',
          'price': data['pricing']?['price'] ?? data['price'] ?? 0.0,
          'image': data['media']?['featuredImage'] ?? data['image'] ?? '',
          'description': data['basicInfo']?['description'] ?? data['description'] ?? '',
          'quantity': data['inventory']?['quantity'] ?? data['quantity'] ?? 0,
          'discount': data['discount']?['percentage'] ?? data['discount'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch products by price range: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDiscountedProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('status.isActive', isEqualTo: true)
          .where('discount.percentage', isGreaterThan: 0)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'basicInfo': data['basicInfo'] ?? {
            'name': data['name'] ?? 'Unknown Product',
            'description': data['description'] ?? '',
          },
          'pricing': data['pricing'] ?? {
            'price': data['price'] ?? 0.0,
          },
          'media': data['media'] ?? {
            'featuredImage': data['image'] ?? '',
          },
          'categorization': data['categorization'] ?? {},
          'inventory': data['inventory'] ?? {
            'quantity': data['quantity'] ?? 0,
            'trackQuantity': true,
          },
          'discount': data['discount'] ?? {
            'percentage': data['discount'] ?? 0.0,
          },
          'details': data['details'] ?? {
            'brand': '',
            'type': '',
            'ingredients': '',
            'size': '',
            'packaging': '',
            'shelfLife': '',
          },
          'status': data['status'] ?? {
            'isActive': true,
          },
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],

          // Legacy fields for backward compatibility
          'name': data['basicInfo']?['name'] ?? data['name'] ?? 'Unknown Product',
          'price': data['pricing']?['price'] ?? data['price'] ?? 0.0,
          'image': data['media']?['featuredImage'] ?? data['image'] ?? '',
          'description': data['basicInfo']?['description'] ?? data['description'] ?? '',
          'quantity': data['inventory']?['quantity'] ?? data['quantity'] ?? 0,
          'discount': data['discount']?['percentage'] ?? data['discount'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch discounted products: $e');
    }
  }
}