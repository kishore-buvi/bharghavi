import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final querySnapshot = await _firestore.collection('categories').get();
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] ?? 'Unknown Category',
        'description': doc.data()['description'] ?? '',
        'image': doc.data()['image'] ?? '',
        'isActive': doc.data()['isActive'] ?? true,
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  Stream<QuerySnapshot> getCategoriesStream() {
    return _firestore.collection('categories').snapshots();
  }

  Future<void> addCategory({
    required String name,
    required String description,
    required File imageFile,
  }) async {
    try {
      final imageUrl = await _uploadImage(imageFile, 'category');
      await _firestore.collection('categories').add({
        'name': name,
        'description': description,
        'image': imageUrl,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _firestore.collection('categories').doc(categoryId).delete();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCarouselImages() async {
    try {
      final querySnapshot = await _firestore
          .collection('carousel_images')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        'imageUrl': doc.data()['imageUrl'] ?? '',
        'title': doc.data()['title'] ?? '',
        'order': doc.data()['order'] ?? 0,
        'isActive': doc.data()['isActive'] ?? true,
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch carousel images: $e');
    }
  }

  Future<void> addCarouselImage(File imageFile) async {
    try {
      final imageUrl = await _uploadImage(imageFile, 'carousel');
      await _firestore.collection('carousel_images').add({
        'imageUrl': imageUrl,
        'title': '',
        'order': FieldValue.increment(1),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add carousel image: $e');
    }
  }

  Future<void> updateCarouselImage(String imageId, File imageFile) async {
    try {
      final imageUrl = await _uploadImage(imageFile, 'carousel');
      await _firestore.collection('carousel_images').doc(imageId).update({
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update carousel image: $e');
    }
  }

  Future<void> deleteCarouselImage(String imageId) async {
    try {
      await _firestore.collection('carousel_images').doc(imageId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete carousel image: $e');
    }
  }

  Future<String> addProduct({
    required String name,
    required String description,
    required double price,
    required int quantity,
    required double discount,
    required File imageFile,
    required String categoryId,
  }) async {
    try {
      final docRef = _firestore.collection('products').doc();
      final imageUrl = await _uploadImage(imageFile, 'product_${docRef.id}');
      final productData = {
        'basicInfo': {
          'name': name,
          'description': description,
          'brand': 'STANDARD OF SPICES',
          'sku': 'SKU-${docRef.id.substring(0, 8).toUpperCase()}',
        },
        'pricing': {
          'price': price,
          'compareAtPrice': null,
          'costPrice': null,
        },
        'inventory': {
          'quantity': quantity,
          'trackInventory': true,
          'lowStockThreshold': 5,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        'media': {
          'featuredImage': imageUrl,
          'images': [imageUrl],
        },
        'categorization': {
          'category': categoryId,
          'subCategory': null,
          'tags': ['organic', 'natural', 'premium'],
        },
        'status': {
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'specifications': {
          'weight': 1.0,
          'dimensions': {'length': 10.0, 'width': 10.0, 'height': 15.0},
          'material': 'Glass',
          'color': 'Transparent',
        },
        'discount': {
          'percentage': discount,
          'isActive': discount > 0,
          'startDate': null,
          'endDate': null,
        },
        'reviews': {
          'averageRating': 0.0,
          'totalReviews': 0,
          'ratingsBreakdown': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
        },
        'seo': {
          'title': name,
          'metaDescription': 'Buy $name at best price. High quality organic product.',
          'urlHandle': name.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9\-]'), ''),
          'keywords': ['organic', 'spices', 'natural', name.toLowerCase()],
        },
        'tags': ['organic', 'natural', 'premium', 'authentic'],
        'shipping': {
          'weight': 1.0,
          'requiresShipping': true,
          'shippingClass': 'standard',
          'handlingTime': 1,
        },
      };
      await docRef.set(productData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String description,
    required double price,
    required int quantity,
    required double discount,
    required String categoryId,
    File? imageFile,
  }) async {
    try {
      final updates = <String, dynamic>{
        'basicInfo.name': name,
        'basicInfo.description': description,
        'pricing.price': price,
        'inventory.quantity': quantity,
        'inventory.lastUpdated': FieldValue.serverTimestamp(),
        'discount.percentage': discount,
        'discount.isActive': discount > 0,
        'categorization.category': categoryId,
        'status.updatedAt': FieldValue.serverTimestamp(),
      };
      if (imageFile != null) {
        final imageUrl = await _uploadImage(imageFile, 'product_$productId');
        updates['media.featuredImage'] = imageUrl;
        updates['media.images'] = FieldValue.arrayUnion([imageUrl]);
      }
      await _firestore.collection('products').doc(productId).update(updates);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<Map<String, dynamic>> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (!doc.exists) throw Exception('Product not found');
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'status.isActive': false,
        'status.deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Stream<QuerySnapshot> getProductsStream() {
    return _firestore.collection('products').snapshots();
  }

  Future<String> _uploadImage(File image, String type) async {
    try {
      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('images/$fileName');
      final uploadTask = await storageRef.putFile(image);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}