//
// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
//
// class FirebaseService {
// final _firestore = FirebaseFirestore.instance;
// final _storage = FirebaseStorage.instance;
//
// Future<List<Map<String, dynamic>>> fetchCategories() async {
// try {
// final querySnapshot = await _firestore.collection('categories').get();
// return querySnapshot.docs.map((doc) => {
// 'id': doc.id,
// 'name': doc.data()['name'] ?? 'Unnamed Category',
// 'description': doc.data()['description'] ?? '',
// 'image': doc.data()['image'] ?? '',
// 'isActive': doc.data()['isActive'] ?? true,
// }).toList();
// } catch (e) {
// print('Error fetching categories: $e');
// throw Exception('Failed to load categories');
// }
// }
//
// Stream<QuerySnapshot> getCategoriesStream() {
// return _firestore.collection('categories').snapshots();
// }
//
// Future<List<Map<String, dynamic>>> fetchCarouselImages() async {
// try {
// final querySnapshot = await _firestore.collection('carousel_images').get();
// return querySnapshot.docs.map((doc) => {
// 'id': doc.id,
// 'imageUrl': doc.data()['imageUrl'] ?? '',
// 'isActive': doc.data()['isActive'] ?? true,
// }).toList();
// } catch (e) {
// print('Error fetching carousel images: $e');
// throw Exception('Failed to load carousel images');
// }
// }
//
// Stream<QuerySnapshot> getProductsStream() {
// return _firestore.collection('products').snapshots();
// }
//
// Future<Map<String, dynamic>> getProduct(String productId) async {
// try {
// final doc = await _firestore.collection('products').doc(productId).get();
// if (!doc.exists) throw Exception('Product not found');
// return doc.data() as Map<String, dynamic>;
// } catch (e) {
// print('Error fetching product: $e');
// throw Exception('Failed to load product');
// }
// }
//
// Future<String> _uploadImage(File image, String type) async {
// try {
// String fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.png';
// Reference storageRef = _storage.ref().child('images/$fileName');
// UploadTask uploadTask = storageRef.putFile(image);
// TaskSnapshot snapshot = await uploadTask;
// return await snapshot.ref.getDownloadURL();
// } catch (e) {
// print('Error uploading image: $e');
// throw Exception('Failed to upload image');
// }
// }
//
// Future<void> addCategory({
// required String name,
// required String description,
// required File imageFile,
// }) async {
// try {
// String imageUrl = await _uploadImage(imageFile, 'category');
// await _firestore.collection('categories').add({
// 'name': name,
// 'description': description,
// 'image': imageUrl,
// 'isActive': true,
// 'createdAt': FieldValue.serverTimestamp(),
// 'updatedAt': FieldValue.serverTimestamp(),
// });
// } catch (e) {
// print('Error adding category: $e');
// throw Exception('Failed to add category');
// }
// }
//
// Future<void> deleteCategory(String categoryId) async {
// try {
// await _firestore.collection('categories').doc(categoryId).delete();
// } catch (e) {
// print('Error deleting category: $e');
// throw Exception('Failed to delete category');
// }
// }
//
// Future<void> addCarouselImage(File imageFile) async {
// try {
// String imageUrl = await _uploadImage(imageFile, 'carousel');
// await _firestore.collection('carousel_images').add({
// 'imageUrl': imageUrl,
// 'isActive': true,
// 'createdAt': FieldValue.serverTimestamp(),
// });
// } catch (e) {
// print('Error adding carousel image: $e');
// throw Exception('Failed to add carousel image');
// }
// }
//
// Future<void> updateCarouselImage(String imageId, File imageFile) async {
// try {
// String imageUrl = await _uploadImage(imageFile, 'carousel');
// await _firestore.collection('carousel_images').doc(imageId).update({
// 'imageUrl': imageUrl,
// 'isActive': true,
// 'updatedAt': FieldValue.serverTimestamp(),
// });
// } catch (e) {
// print('Error updating carousel image: $e');
// throw Exception('Failed to update carousel image');
// }
// }
//
// Future<void> deleteCarouselImage(String imageId) async {
// try {
// await _firestore.collection('carousel_images').doc(imageId).delete();
// } catch (e) {
// print('Error deleting carousel image: $e');
// throw Exception('Failed to delete carousel image');
// }
// }
//
// Future<void> addProduct({
// required String name,
// required String description,
// required double price,
// required int quantity,
// required double discount,
// required File imageFile,
// required String categoryId,
// }) async {
// try {
// String imageUrl = await _uploadImage(imageFile, 'product');
// await _firestore.collection('products').add({
// 'basicInfo': {
// 'name': name,
// 'description': description,
// },
// 'pricing': {'price': price},
// 'media': {'featuredImage': imageUrl},
// 'categorization': {'category': categoryId},
// 'inventory': {'quantity': quantity, 'trackQuantity': true},
// 'discount': {'percentage': discount},
// 'status': {'isActive': true},
// 'createdAt': FieldValue.serverTimestamp(),
// 'updatedAt': FieldValue.serverTimestamp(),
// });
// } catch (e) {
// print('Error adding product: $e');
// throw Exception('Failed to add product: $e');
// }
// }
//
// Future<void> updateProduct({
// required String productId,
// required String name,
// required String description,
// required double price,
// required int quantity,
// required double discount,
// required String categoryId,
// File? imageFile,
// }) async {
// try {
// String? imageUrl;
// if (imageFile != null) {
// imageUrl = await _uploadImage(imageFile, 'product');
// } else {
// final product = await getProduct(productId);
// imageUrl = product['media']['featuredImage'] ?? '';
// }
// await _firestore.collection('products').doc(productId).update({
// 'basicInfo': {
// 'name': name,
// 'description': description,
// },
// 'pricing': {'price': price},
// 'media': {'featuredImage': imageUrl},
// 'categorization': {'category': categoryId},
// 'inventory': {'quantity': quantity, 'trackQuantity': true},
// 'discount': {'percentage': discount},
// 'status': {'isActive': true},
// 'updatedAt': FieldValue.serverTimestamp(),
// });
// } catch (e) {
// print('Error updating product: $e');
// throw Exception('Failed to update product: $e');
// }
// }
//
// Future<void> deleteProduct(String productId) async {
// try {
// await _firestore.collection('products').doc(productId).delete();
// } catch (e) {
// print('Error deleting product: $e');
// throw Exception('Failed to delete product');
// }
// }
// }
