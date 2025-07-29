
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/productList/imageService.dart';
import '../../screens/productList/productCard.dart';
import '../../screens/productList/productForm.dart';
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
final _imageService = ImageService();
final GlobalKey _carouselKey = GlobalKey();
List<Map<String, dynamic>> _categories = [];
List<Map<String, dynamic>> _carouselImages = [];
String? _searchQuery;
String? _filterOption = 'All';
String? _editingProductId;

@override
void initState() {
super.initState();
_fetchCategories();
_fetchCarouselImages();
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

void _showProductForm({Map<String, dynamic>? product}) {
showModalBottomSheet(
context: context,
isScrollControlled: true,
builder: (context) => SingleChildScrollView(
child: Container(
padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
child: ProductForm(
product: product,
categories: _categories,
imageService: _imageService,
onSubmit: (data, image, productId, categoryId) async {
try {
if (productId != null) {
await _firestoreService.updateProduct(
productId: productId,
name: data['name'],
description: data['description'],
price: double.parse(data['price']),
quantity: int.parse(data['quantity']),
discount: double.parse(data['discount']),
imageFile: image,
categoryId: categoryId!,
);
_showSnackBar('Product updated successfully');
} else {
await _firestoreService.addProduct(
name: data['name'],
description: data['description'],
price: double.parse(data['price']),
quantity: int.parse(data['quantity']),
discount: double.parse(data['discount']),
imageFile: image!,
categoryId: categoryId!,
);
_showSnackBar('Product added successfully');
}
Navigator.pop(context);
} catch (e) {
_showSnackBar('Error: ${e.toString()}');
}
},
),
),
),
);
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
onPressed: () async {
final file = await _imageService.pickImage(context);
if (file != null && mounted) {
setState(() => _editingProductId = image['id']);
await _firestoreService.updateCarouselImage(image['id'], file);
_fetchCarouselImages();
_showSnackBar('Carousel image updated');
}
},
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
onPressed: () => _firestoreService.deleteCarouselImage(image['id']).then((_) {
_fetchCarouselImages();
_showSnackBar('Carousel image deleted');
}),
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
onPressed: () async {
final file = await _imageService.pickImage(context);
if (file != null && mounted) {
await _firestoreService.addCarouselImage(file);
_fetchCarouselImages();
_showSnackBar('Carousel image added');
}
},
child: const Text('Add Carousel Image'),
),
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
ElevatedButton(
onPressed: () => _showProductForm(),
child: const Text('Add New Product'),
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
final aPrice = aData['pricing']['price']?.toDouble() ?? 0.0;
final bPrice = bData['pricing']['price']?.toDouble() ?? 0.0;
return aPrice.compareTo(bPrice);
});
break;
case 'Price: High to Low':
products.sort((a, b) {
final aData = a.data() as Map<String, dynamic>;
final bData = b.data() as Map<String, dynamic>;
final aPrice = bData['pricing']['price']?.toDouble() ?? 0.0;
final bPrice = aData['pricing']['price']?.toDouble() ?? 0.0;
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
return ProductCard(
product: productData,
isAdminMode: true,
onEdit: () => _showProductForm(product: productData),
onDelete: () {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Delete Product'),
content: Text('Are you sure you want to delete "${productData['basicInfo']['name']}"?'),
actions: [
TextButton(
onPressed: () {
Navigator.of(context).pop();
_firestoreService.deleteProduct(product.id).then((_) {
_showSnackBar('Product deleted');
});
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
onAddToCart: () {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('${productData['basicInfo']['name']} added to cart!'),
duration: const Duration(seconds: 2),
),
);
},
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
