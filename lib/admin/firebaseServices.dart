import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final querySnapshot = await _firestore.collection('categories').get();
    return querySnapshot.docs.map((doc) => {
      'id': doc.id,
      'name': doc.data()['name'],
      'description': doc.data()['description'] ?? '',
      'image': doc.data()['image'] ?? '',
      'isActive': doc.data()['isActive'] ?? true,
    }).toList();
  }

  Stream<QuerySnapshot> getCategoriesStream() {
    return _firestore.collection('categories').snapshots();
  }

  Future<List<Map<String, dynamic>>> fetchCarouselImages() async {
    final querySnapshot = await _firestore.collection('carousel_images').get();
    return querySnapshot.docs.map((doc) => {
      'id': doc.id,
      'imageUrl': doc.data()['imageUrl'],
      'isActive': doc.data()['isActive'] ?? true,
    }).toList();
  }

  Stream<QuerySnapshot> getProductsStream() {
    return _firestore.collection('products').snapshots();
  }

  Future<Map<String, dynamic>> getProduct(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    return doc.data() as Map<String, dynamic>;
  }

  Future<String> _uploadImage(File image, String type) async {
    try {
      String fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.png';
      Reference storageRef = _storage.ref().child('images/$fileName');
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> addCategory({
    required String name,
    required String description,
    required File imageFile,
  }) async {
    String imageUrl = await _uploadImage(imageFile, 'category');
    await _firestore.collection('categories').add({
      'name': name,
      'description': description,
      'image': imageUrl,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).delete();
  }

  Future<void> addCarouselImage(File imageFile) async {
    String imageUrl = await _uploadImage(imageFile, 'carousel');
    await _firestore.collection('carousel_images').add({
      'imageUrl': imageUrl,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCarouselImage(String imageId, File imageFile) async {
    String imageUrl = await _uploadImage(imageFile, 'carousel');
    await _firestore.collection('carousel_images').doc(imageId).update({
      'imageUrl': imageUrl,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCarouselImage(String imageId) async {
    await _firestore.collection('carousel_images').doc(imageId).delete();
  }

  Future<void> addProduct({
    required String name,
    required String description,
    required double price,
    required int quantity,
    required double discount,
    required File imageFile,
    required String categoryId,
  }) async {
    String imageUrl = await _uploadImage(imageFile, 'product');
    await _firestore.collection('products').add({
      'basicInfo': {
        'name': name,
        'description': description,
      },
      'pricing': {'price': price},
      'media': {'featuredImage': imageUrl},
      'categorization': {'category': categoryId},
      'inventory': {'quantity': quantity, 'trackQuantity': true},
      'discount': {'percentage': discount},
      'status': {'isActive': true},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadImage(imageFile, 'product');
    } else {
      final product = await getProduct(productId);
      imageUrl = product['media']['featuredImage'];
    }
    await _firestore.collection('products').doc(productId).update({
      'basicInfo': {
        'name': name,
        'description': description,
      },
      'pricing': {'price': price},
      'media': {'featuredImage': imageUrl},
      'categorization': {'category': categoryId},
      'inventory': {'quantity': quantity, 'trackQuantity': true},
      'discount': {'percentage': discount},
      'status': {'isActive': true},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }
}