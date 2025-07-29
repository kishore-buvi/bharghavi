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
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['basicInfo']['name'],
        'price': doc.data()['pricing']['price'],
        'image': doc.data()['media']['featuredImage'] ?? '',
        'quantity': doc.data()['inventory']['quantity'] ?? 0,
        'discount': doc.data()['discount']['percentage'] ?? 0,
        'description': doc.data()['basicInfo']['description'] ?? '',
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to load products');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCarouselImages() async {
    try {
      final querySnapshot = await _firestore.collection('carousel_images').get();
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        'imageUrl': doc.data()['imageUrl'],
        'isActive': doc.data()['isActive'] ?? true,
      }).toList();
    } catch (e) {
      print('Error fetching carousel images: $e');
      throw Exception('Failed to load carousel images');
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.png';
      Reference storageRef = _storage.ref().child('images/$fileName');
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }

  Future<void> addProduct(String categoryId, Map<String, dynamic> data, File? image) async {
    try {
      String imageUrl = image != null ? await _uploadImage(image) : '';
      await _firestore.collection('products').add({
        'basicInfo': {
          'name': data['name'],
          'description': '',
        },
        'pricing': {'price': double.parse(data['price'])},
        'media': {'featuredImage': imageUrl},
        'categorization': {'category': categoryId},
        'inventory': {'quantity': int.parse(data['quantity'])},
        'discount': {'percentage': double.parse(data['discount'])},
        'status': {'isActive': true},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding product: $e');
      throw Exception('Failed to add product');
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data, File? image) async {
    try {
      String imageUrl = image != null
          ? await _uploadImage(image)
          : (await _firestore.collection('products').doc(productId).get()).data()?['media']['featuredImage'] ?? '';
      await _firestore.collection('products').doc(productId).update({
        'basicInfo': {
          'name': data['name'],
          'description': '',
        },
        'pricing': {'price': double.parse(data['price'])},
        'media': {'featuredImage': imageUrl},
        'inventory': {'quantity': int.parse(data['quantity'])},
        'discount': {'percentage': double.parse(data['discount'])},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product: $e');
      throw Exception('Failed to update product');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      print('Error deleting product: $e');
      throw Exception('Failed to delete product');
    }
  }
}