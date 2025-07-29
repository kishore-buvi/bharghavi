
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../screens/productList/productCard.dart';
import '../firebaseServices.dart';
import '../permissionServices.dart';

class ProductTab extends StatefulWidget {
const ProductTab({Key? key}) : super(key: key);

@override
_ProductTabState createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
final _firestoreService = FirebaseService();
final _permissionService = PermissionService();
final _productNameController = TextEditingController(text: 'Bhargavi Oil Store ');
final _productDescriptionController = TextEditingController();
final _productPriceController = TextEditingController();
final _productQuantityController = TextEditingController();
final _productDiscountController = TextEditingController();
final _productWeightController = TextEditingController(); // Added weight controller
String? _selectedCategoryId;
File? _productImageFile;
File? _carouselImageFile;
String? _searchQuery;
String? _filterOption;
String? _editingCarouselId;
List<Map<String, dynamic>> _categories = [];
List<Map<String, dynamic>> _carouselImages = [];
final ImagePicker _picker = ImagePicker();
final GlobalKey _carouselKey = GlobalKey();

@override
void initState() {
super.initState();
_fetchCategories();
_fetchCarouselImages();
}

@override
void dispose() {
_productNameController.dispose();
_productDescriptionController.dispose();
_productPriceController.dispose();
_productQuantityController.dispose();
_productDiscountController.dispose();
_productWeightController.dispose(); // Dispose weight controller
super.dispose();
}

Future<void> _fetchCategories() async {
try {
final categories = await _firestoreService.fetchCategories();
if (mounted) setState(() => _categories = categories);
} catch (e) {
_showSnackBar('Failed to load categories.');
}
}

Future<void> _fetchCarouselImages() async {
try {
final carouselImages = await _firestoreService.fetchCarouselImages();
if (mounted) setState(() => _carouselImages = carouselImages);
} catch (e) {
_showSnackBar('Failed to load carousel images.');
}
}

Future<void> _pickImage({bool isCarousel = false}) async {
try {
final hasPermission = await _permissionService.requestPermissions(context);
if (!hasPermission) return;

final pickedFile = await _picker.pickImage(
source: ImageSource.gallery,
maxWidth: 512,
maxHeight: 512,
imageQuality: 70,
);

if (pickedFile != null && mounted) {
setState(() {
if (isCarousel) {
_carouselImageFile = File(pickedFile.path);
} else {
_productImageFile = File(pickedFile.path);
}
});
}
} catch (e) {
_showSnackBar('Failed to pick image. Please try again.');
}
}

Future<void> _addCarouselImage() async {
if (_carouselImageFile == null) {
_showSnackBar('Please select an image');
return;
}

try {
await _firestoreService.addCarouselImage(_carouselImageFile!);
if (mounted) {
setState(() {
_carouselImageFile = null;
_editingCarouselId = null;
});
_fetchCarouselImages();
_showSnackBar('Carousel image added successfully');
}
} catch (e) {
_showSnackBar('Failed to add carousel image');
}
}

Future<void> _updateCarouselImage(String imageId) async {
if (_carouselImageFile == null) {
_showSnackBar('Please select an image');
return;
}

try {
await _firestoreService.updateCarouselImage(imageId, _carouselImageFile!);
if (mounted) {
setState(() {
_carouselImageFile = null;
_editingCarouselId = null;
});
_fetchCarouselImages();
_showSnackBar('Carousel image updated successfully');
}
} catch (e) {
_showSnackBar('Failed to update carousel image');
}
}

Future<void> _deleteCarouselImage(String imageId) async {
try {
await _firestoreService.deleteCarouselImage(imageId);
_fetchCarouselImages();
_showSnackBar('Carousel image deleted');
} catch (e) {
_showSnackBar('Failed to delete carousel image');
}
}

Future<void> _addProduct() async {
if (_productNameController.text.isEmpty ||
_productDescriptionController.text.isEmpty ||
_productPriceController.text.isEmpty ||
_productQuantityController.text.isEmpty ||
_productDiscountController.text.isEmpty ||
_productWeightController.text.isEmpty || // Validate weight
_productImageFile == null ||
_selectedCategoryId == null) {
_showSnackBar('Please fill all fields and select an image and category');
return;
}

try {
await _firestoreService.addProduct(
name: _productNameController.text,
description: _productDescriptionController.text,
price: double.parse(_productPriceController.text),
quantity: int.parse(_productQuantityController.text),
discount: double.parse(_productDiscountController.text),
// Add weight
imageFile: _productImageFile!,
categoryId: _selectedCategoryId!,
);
_clearProductForm();
_showSnackBar('Product added successfully');
} catch (e) {
_showSnackBar('Failed to add product');
}
}

Future<void> _updateProduct(String productId) async {
if (_productNameController.text.isEmpty ||
_productDescriptionController.text.isEmpty ||
_productPriceController.text.isEmpty ||
_productQuantityController.text.isEmpty ||
_productDiscountController.text.isEmpty ||
_productWeightController.text.isEmpty || // Validate weight
(_productImageFile == null && (await _firestoreService.getProduct(productId))['media']['featuredImage'] == null)) {
_showSnackBar('Please fill all fields and select an image');
return;
}

try {
await _firestoreService.updateProduct(
productId: productId,
name: _productNameController.text,
description: _productDescriptionController.text,
price: double.parse(_productPriceController.text),
quantity: int.parse(_productQuantityController.text),
discount: double.parse(_productDiscountController.text),
// Add weight
categoryId: _selectedCategoryId!,
imageFile: _productImageFile,
);
_clearProductForm();
_showSnackBar('Product updated successfully');
} catch (e) {
_showSnackBar('Failed to update product');
}
}

Future<void> _deleteProduct(String productId) async {
try {
await _firestoreService.deleteProduct(productId);
_showSnackBar('Product deleted');
} catch (e) {
_showSnackBar('Failed to delete product');
}
}

void _editProduct(Map<String, dynamic> product) {
_productNameController.text = product['basicInfo']['name'];
_productDescriptionController.text = product['basicInfo']['description'] ?? '';
_productPriceController.text = product['pricing']['price'].toString();
_productQuantityController.text = product['inventory']['quantity'].toString();
_productDiscountController.text = product['discount']['percentage'].toString();
_productWeightController.text = product['specifications']?['weight']?.toString() ?? ''; // Load weight
_selectedCategoryId = product['categorization']['category'];
if (mounted) setState(() => _productImageFile = null);
}

void _editCarouselImage(Map<String, dynamic> image) {
if (mounted) setState(() {
_carouselImageFile = null;
_editingCarouselId = image['id'];
});
}

void _clearProductForm() {
_productNameController.text = 'Bhargavi Oil Store ';
_productDescriptionController.clear();
_productPriceController.clear();
_productQuantityController.clear();
_productDiscountController.clear();
_productWeightController.clear(); // Clear weight
if (mounted) setState(() {
_productImageFile = null;
_selectedCategoryId = null;
});
}

void _showSnackBar(String message) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
}

@override
Widget build(BuildContext context) {
return SingleChildScrollView(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const Text('Carousel Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
_carouselImages.isNotEmpty
? CarouselSlider(
key: _carouselKey,
options: CarouselOptions(
height: 200,
enlargeCenterPage: true,
autoPlay: true,
aspectRatio: 16 / 9,
autoPlayCurve: Curves.fastOutSlowIn,
enableInfiniteScroll: true,
autoPlayAnimationDuration: const Duration(milliseconds: 800),
viewportFraction: 0.8,
),
items: _carouselImages.map((image) {
return Builder(
builder: (BuildContext context) {
return Container(
width: MediaQuery.of(context).size.width,
margin: const EdgeInsets.symmetric(horizontal: 5.0),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(8.0),
),
child: Stack(
children: [
ClipRRect(
borderRadius: BorderRadius.circular(8.0),
child: CachedNetworkImage(
imageUrl: image['imageUrl'],
fit: BoxFit.cover,
height: 200,
width: double.infinity,
placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
errorWidget: (context, url, error) => const Icon(Icons.error),
),
),
Positioned(
top: 5,
right: 5,
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
decoration: BoxDecoration(
color: Colors.black54,
borderRadius: BorderRadius.circular(20),
),
child: IconButton(
icon: const Icon(Icons.edit, color: Colors.white, size: 20),
onPressed: () => _editCarouselImage(image),
),
),
const SizedBox(width: 5),
Container(
decoration: BoxDecoration(
color: Colors.black54,
borderRadius: BorderRadius.circular(20),
),
child: IconButton(
icon: const Icon(Icons.delete, color: Colors.red, size: 20),
onPressed: () => _deleteCarouselImage(image['id']),
),
),
],
),
),
],
),
);
},
);
}).toList(),
)
    : Container(
height: 200,
color: Colors.grey[300],
child: const Center(child: Text('No carousel images available')),
),
const SizedBox(height: 10),
ElevatedButton(
onPressed: () => _pickImage(isCarousel: true),
child: Text(_editingCarouselId != null ? 'Update Carousel Image' : 'Add Carousel Image'),
),
if (_carouselImageFile != null) ...[
const SizedBox(height: 10),
Center(
child: Image.file(
_carouselImageFile!,
height: 100,
width: 100,
fit: BoxFit.cover,
),
),
const SizedBox(height: 10),
ElevatedButton(
onPressed: _editingCarouselId != null
? () => _updateCarouselImage(_editingCarouselId!)
    : _addCarouselImage,
child: Text(_editingCarouselId != null ? 'Save Update' : 'Upload Carousel Image'),
),
],
const SizedBox(height: 20),
Row(
children: [
Expanded(
flex: 2,
child: TextField(
onChanged: (value) => setState(() => _searchQuery = value),
decoration: const InputDecoration(
labelText: 'Search Products',
suffixIcon: Icon(Icons.search),
border: OutlineInputBorder(),
contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
),
),
const SizedBox(width: 10),
Expanded(
child: DropdownButtonFormField<String>(
value: _filterOption,
hint: const Text('Filter'),
decoration: const InputDecoration(
border: OutlineInputBorder(),
contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
),
isExpanded: true,
items: ['All', 'Price: Low to High', 'Price: High to Low', 'Active', 'Inactive']
    .map((String value) => DropdownMenuItem<String>(
value: value,
child: Text(value, style: const TextStyle(fontSize: 12)),
))
    .toList(),
onChanged: (value) => setState(() => _filterOption = value),
),
),
],
),
const SizedBox(height: 20),
const Text('Add/Edit Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
TextField(
controller: _productNameController,
decoration: const InputDecoration(
labelText: 'Product Name',
border: OutlineInputBorder(),
),
),
const SizedBox(height: 10),
TextField(
controller: _productDescriptionController,
decoration: const InputDecoration(
labelText: 'Description',
border: OutlineInputBorder(),
),
maxLines: 3,
),
const SizedBox(height: 10),
Row(
children: [
Expanded(
child: TextField(
controller: _productPriceController,
decoration: const InputDecoration(
labelText: 'Price',
border: OutlineInputBorder(),
prefixText: '₹',
),
keyboardType: TextInputType.number,
),
),
const SizedBox(width: 10),
Expanded(
child: TextField(
controller: _productQuantityController,
decoration: const InputDecoration(
labelText: 'Quantity',
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
),
),
],
),
const SizedBox(height: 10),
TextField(
controller: _productDiscountController,
decoration: const InputDecoration(
labelText: 'Discount %',
border: OutlineInputBorder(),
suffixText: '%',
),
keyboardType: TextInputType.number,
),
const SizedBox(height: 10),
TextField(
controller: _productWeightController, // Added weight field
decoration: const InputDecoration(
labelText: 'Weight (kg)',
border: OutlineInputBorder(),
suffixText: 'kg',
),
keyboardType: TextInputType.number,
),
const SizedBox(height: 10),
Row(
children: [
Expanded(
child: ElevatedButton(
onPressed: () => _pickImage(),
child: const Text('Pick Product Image'),
),
),
if (_productImageFile != null) ...[
const SizedBox(width: 10),
Container(
width: 60,
height: 60,
decoration: BoxDecoration(
border: Border.all(color: Colors.grey),
borderRadius: BorderRadius.circular(8),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(8),
child: Image.file(
_productImageFile!,
fit: BoxFit.cover,
),
),
),
],
],
),
const SizedBox(height: 10),
DropdownButtonFormField<String>(
value: _selectedCategoryId,
hint: const Text('Select Category'),
decoration: const InputDecoration(
border: OutlineInputBorder(),
),
items: _categories.map((category) => DropdownMenuItem<String>(
value: category['id'],
child: Text(category['name']),
)).toList(),
onChanged: (value) => setState(() => _selectedCategoryId = value),
),
const SizedBox(height: 10),
ElevatedButton(
onPressed: _addProduct,
child: const Text('Add Product'),
),
const SizedBox(height: 20),
const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
StreamBuilder<QuerySnapshot>(
stream: _firestoreService.getProductsStream(),
builder: (context, snapshot) {
if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

List<QueryDocumentSnapshot> products = snapshot.data!.docs;

if (_searchQuery != null && _searchQuery!.isNotEmpty) {
products = products.where((product) {
final productData = product.data() as Map<String, dynamic>;
final name = productData['basicInfo']['name']?.toString().toLowerCase() ?? '';
final description = productData['basicInfo']['description']?.toString().toLowerCase() ?? '';
final searchLower = _searchQuery!.toLowerCase();
return name.contains(searchLower) || description.contains(searchLower);
}).toList();
}

if (_filterOption != null && _filterOption != 'All') {
switch (_filterOption) {
case 'Price: Low to High':
products.sort((a, b) {
final aData = a.data() as Map<String, dynamic>;
final bData = b.data() as Map<String, dynamic>;
final aPrice = aData['pricing']['price'] ?? 0.0;
final bPrice = bData['pricing']['price'] ?? 0.0;
return aPrice.compareTo(bPrice);
});
break;
case 'Price: High to Low':
products.sort((a, b) {
final aData = a.data() as Map<String, dynamic>;
final bData = b.data() as Map<String, dynamic>;
final aPrice = bData['pricing']['price'] ?? 0.0;
final bPrice = aData['pricing']['price'] ?? 0.0;
return bPrice.compareTo(aPrice);
});
break;
case 'Active':
products = products.where((product) {
final productData = product.data() as Map<String, dynamic>;
return productData['status']['isActive'] == true;
}).toList();
break;
case 'Inactive':
products = products.where((product) {
final productData = product.data() as Map<String, dynamic>;
return productData['status']['isActive'] == false;
}).toList();
break;
}
}

if (products.isEmpty) {
return const Center(child: Text('No products found', style: TextStyle(fontSize: 16)));
}

return ListView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
itemCount: products.length,
itemBuilder: (context, index) {
final product = products[index];
final productData = product.data() as Map<String, dynamic>;

// Normalize discount field to ensure consistent structure
final adjustedProductData = Map<String, dynamic>.from(productData);
if (adjustedProductData['discount'] != null) {
if (adjustedProductData['discount']['percentage'] is double) {
// Already correct, no change needed
} else if (adjustedProductData['discount']['percentage'] is Map) {
// Handle nested structure
adjustedProductData['discount'] = {
'percentage': adjustedProductData['discount']['percentage']['value'] ?? 0.0,
};
} else {
// Invalid or missing, default to 0.0
adjustedProductData['discount'] = {'percentage': 0.0};
}
} else {
adjustedProductData['discount'] = {'percentage': 0.0};
}

// Ensure specifications field exists
adjustedProductData['specifications'] ??= {'weight': 0.0};

return ProductCard(
product: adjustedProductData,
isAdminMode: true,
onEdit: () {
_editProduct(adjustedProductData);
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Edit Product'),
content: const Text('Product details loaded in the form above. Make your changes and click "Update Product".'),
actions: [
TextButton(
onPressed: () {
Navigator.of(context).pop();
_updateProduct(product.id);
},
child: const Text('Update Product'),
),
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: const Text('Cancel'),
),
],
),
);
},
onDelete: () {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Delete Product'),
content: Text('Are you sure you want to delete "${adjustedProductData['basicInfo']['name']}"?'),
actions: [
TextButton(
onPressed: () {
Navigator.of(context).pop();
_deleteProduct(product.id);
},
child: const Text('Delete', style: TextStyle(color: Colors.red)),
),
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: const Text('Cancel'),
),
],
),
);
},
onAddToCart: () {},
);
},
);
},
),
],
),
);
}
}
