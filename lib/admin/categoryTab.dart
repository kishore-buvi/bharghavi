// import 'dart:io';
// import 'package:bharghavi/admin/permissionServices.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:cached_network_image/cached_network_image.dart';
//
// import 'firebaseServices.dart';
//
//
// class CategoryTab extends StatefulWidget {
//   const CategoryTab({Key? key}) : super(key: key);
//
//   @override
//   _CategoryTabState createState() => _CategoryTabState();
// }
//
// class _CategoryTabState extends State<CategoryTab> {
//   final _firestoreService = FirebaseService();
//   final _permissionService = PermissionService();
//   final _categoryNameController = TextEditingController();
//   final _categoryDescriptionController = TextEditingController();
//   File? _categoryImageFile;
//   final ImagePicker _picker = ImagePicker();
//   List<Map<String, dynamic>> _categories = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchCategories();
//   }
//
//   @override
//   void dispose() {
//     _categoryNameController.dispose();
//     _categoryDescriptionController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _fetchCategories() async {
//     try {
//       final categories = await _firestoreService.fetchCategories();
//       if (mounted) {
//         setState(() => _categories = categories);
//       }
//     } catch (e) {
//       _showSnackBar('Failed to load categories.');
//     }
//   }
//
//   Future<void> _pickImage() async {
//     try {
//       final hasPermission = await _permissionService.requestPermissions(context);
//       if (!hasPermission) return;
//
//       final pickedFile = await _picker.pickImage(
//         source: ImageSource.gallery,
//         maxWidth: 512,
//         maxHeight: 512,
//         imageQuality: 70,
//       );
//
//       if (pickedFile != null && mounted) {
//         setState(() => _categoryImageFile = File(pickedFile.path));
//       }
//     } catch (e) {
//       _showSnackBar('Failed to pick image. Please try again.');
//     }
//   }
//
//   Future<void> _addCategory() async {
//     if (_categoryNameController.text.isEmpty || _categoryImageFile == null) {
//       _showSnackBar('Please enter a category name and select an image');
//       return;
//     }
//
//     try {
//       await _firestoreService.addCategory(
//         name: _categoryNameController.text,
//         description: _categoryDescriptionController.text,
//         imageFile: _categoryImageFile!,
//       );
//       _clearForm();
//       _fetchCategories();
//       _showSnackBar('Category added successfully');
//     } catch (e) {
//       _showSnackBar('Failed to add category');
//     }
//   }
//
//   Future<void> _deleteCategory(String categoryId) async {
//     try {
//       await _firestoreService.deleteCategory(categoryId);
//       _fetchCategories();
//       _showSnackBar('Category deleted');
//     } catch (e) {
//       _showSnackBar('Failed to delete category');
//     }
//   }
//
//   void _clearForm() {
//     _categoryNameController.clear();
//     _categoryDescriptionController.clear();
//     if (mounted) setState(() => _categoryImageFile = null);
//   }
//
//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         children: [
//           TextField(
//             controller: _categoryNameController,
//             decoration: const InputDecoration(labelText: 'Category Name'),
//           ),
//           const SizedBox(height: 10),
//           TextField(
//             controller: _categoryDescriptionController,
//             decoration: const InputDecoration(labelText: 'Description'),
//           ),
//           const SizedBox(height: 10),
//           ElevatedButton(
//             onPressed: _pickImage,
//             child: const Text('Pick Category Image'),
//           ),
//           if (_categoryImageFile != null) ...[
//             const SizedBox(height: 10),
//             Image.file(
//               _categoryImageFile!,
//               height: 100,
//               width: 100,
//               fit: BoxFit.cover,
//             ),
//           ],
//           const SizedBox(height: 10),
//           ElevatedButton(
//             onPressed: _addCategory,
//             child: const Text('Add Category'),
//           ),
//           const SizedBox(height: 20),
//           Expanded(
//             child: StreamBuilder(
//               stream: _firestoreService.getCategoriesStream(),
//               builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
//                 if (!snapshot.hasData) return const CircularProgressIndicator();
//                 final categories = snapshot.data!.docs;
//                 return ListView.builder(
//                   itemCount: categories.length,
//                   itemBuilder: (context, index) {
//                     final category = categories[index];
//                     return Card(
//                       color: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: ListTile(
//                         leading: category['image'].isNotEmpty
//                             ? CachedNetworkImage(
//                           imageUrl: category['image'],
//                           width: 50,
//                           height: 50,
//                           fit: BoxFit.cover,
//                           placeholder: (context, url) => const CircularProgressIndicator(),
//                           errorWidget: (context, url, error) => const Icon(Icons.error),
//                         )
//                             : const Icon(Icons.image, size: 50, color: Colors.grey),
//                         title: Text(category['name']),
//                         subtitle: Text(category['description'] ?? ''),
//                         trailing: IconButton(
//                           icon: const Icon(Icons.delete, color: Colors.red),
//                           onPressed: () => _deleteCategory(category.id),
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }