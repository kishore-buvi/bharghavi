import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminScreen extends StatefulWidget {
  final bool isAdminMode;

  const AdminScreen({Key? key, this.isAdminMode = true}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  late TabController _tabController;
  final _categoryNameController = TextEditingController();
  final _categoryDescriptionController = TextEditingController();
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  String? _selectedCategoryId;
  File? _categoryImageFile;
  File? _productImageFile;
  File? _carouselImageFile;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _carouselImages = [];
  String? _searchQuery;
  String? _filterOption;
  String? _editingCarouselId;

  final ImagePicker _picker = ImagePicker();
  final GlobalKey _carouselKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCategories();
    _fetchCarouselImages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoryNameController.dispose();
    _categoryDescriptionController.dispose();
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final querySnapshot = await _firestore.collection('categories').get();
      if (mounted) {
        setState(() {
          _categories = querySnapshot.docs.map((doc) => {
            'id': doc.id,
            'name': doc.data()['name'],
            'description': doc.data()['description'] ?? '',
            'image': doc.data()['image'] ?? '',
            'isActive': doc.data()['isActive'] ?? true,
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load categories.')),
        );
      }
    }
  }

  Future<void> _fetchCarouselImages() async {
    try {
      final querySnapshot = await _firestore.collection('carousel_images').get();
      if (mounted) {
        setState(() {
          _carouselImages = querySnapshot.docs.map((doc) => {
            'id': doc.id,
            'imageUrl': doc.data()['imageUrl'],
            'isActive': doc.data()['isActive'] ?? true,
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching carousel images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load carousel images.')),
        );
      }
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      Permission targetPermission = sdkInt >= 33 ? Permission.photos : Permission.storage;

      final status = await targetPermission.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      }
      final requestStatus = await targetPermission.request();
      if (requestStatus.isGranted) return true;
      if (requestStatus.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission denied. Please allow access to photos.'),
            action: SnackBarAction(label: 'Retry', onPressed: _requestPermissions),
          ),
        );
      }
      return false;
    } catch (e) {
      print('Error requesting permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission error. Please try again.')),
        );
      }
      return false;
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('This app needs access to your photos to upload images. Please enable it in app settings.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Settings'),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(bool isCategory, {bool isCarousel = false}) async {
    try {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) return;

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          if (isCategory) _categoryImageFile = File(pickedFile.path);
          else if (isCarousel) _carouselImageFile = File(pickedFile.path);
          else _productImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image. Please try again.')),
        );
      }
    }
  }

  Future<String> _uploadImage(File image, String type) async {
    try {
      String fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.png';
      Reference storageRef = _storage.ref().child('images/$fileName');
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }

  Future<void> _addCarouselImage() async {
    if (_carouselImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image')),
        );
      }
      return;
    }

    try {
      String imageUrl = await _uploadImage(_carouselImageFile!, 'carousel');
      await _firestore.collection('carousel_images').add({
        'imageUrl': imageUrl,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _carouselImageFile = null;
          _editingCarouselId = null;
        });
        _fetchCarouselImages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carousel image added successfully')),
        );
      }
    } catch (e) {
      print('Error adding carousel image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add carousel image')),
        );
      }
    }
  }

  Future<void> _updateCarouselImage(String imageId) async {
    if (_carouselImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image')),
        );
      }
      return;
    }

    try {
      String imageUrl = await _uploadImage(_carouselImageFile!, 'carousel');
      await _firestore.collection('carousel_images').doc(imageId).update({
        'imageUrl': imageUrl,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _carouselImageFile = null;
          _editingCarouselId = null;
        });
        _fetchCarouselImages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carousel image updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating carousel image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update carousel image')),
        );
      }
    }
  }

  Future<void> _deleteCarouselImage(String imageId) async {
    try {
      await _firestore.collection('carousel_images').doc(imageId).delete();
      if (mounted) {
        _fetchCarouselImages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carousel image deleted')),
        );
      }
    } catch (e) {
      print('Error deleting carousel image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete carousel image')),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    if (_categoryNameController.text.isEmpty || _categoryImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a category name and select an image')),
        );
      }
      return;
    }

    try {
      String imageUrl = await _uploadImage(_categoryImageFile!, 'category');
      await _firestore.collection('categories').add({
        'name': _categoryNameController.text,
        'description': _categoryDescriptionController.text,
        'image': imageUrl,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _clearCategoryForm();
        _fetchCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category added successfully')),
        );
      }
    } catch (e) {
      print('Error adding category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add category')),
        );
      }
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await _firestore.collection('categories').doc(categoryId).delete();
      if (mounted) {
        _fetchCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted')),
        );
      }
    } catch (e) {
      print('Error deleting category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete category')),
        );
      }
    }
  }

  Future<void> _updateProduct(String productId) async {
    if (_productNameController.text.isEmpty ||
        _productDescriptionController.text.isEmpty ||
        _productPriceController.text.isEmpty ||
        (_productImageFile == null && (await _firestore.collection('products').doc(productId).get()).data()?['media']['featuredImage'] == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields and select an image')),
        );
      }
      return;
    }

    try {
      String imageUrl = _productImageFile != null
          ? await _uploadImage(_productImageFile!, 'product')
          : (await _firestore.collection('products').doc(productId).get()).data()?['media']['featuredImage'];
      await _firestore.collection('products').doc(productId).update({
        'basicInfo': {
          'name': _productNameController.text,
          'description': _productDescriptionController.text,
        },
        'pricing': {'price': double.parse(_productPriceController.text)},
        'media': {'featuredImage': imageUrl},
        'categorization': {'category': _selectedCategoryId},
        'inventory': {'quantity': 100, 'trackQuantity': true},
        'status': {'isActive': true},
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _clearProductForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update product')),
        );
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
      }
    } catch (e) {
      print('Error deleting product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete product')),
        );
      }
    }
  }

  Future<void> _addProduct() async {
    if (_productNameController.text.isEmpty ||
        _productDescriptionController.text.isEmpty ||
        _productPriceController.text.isEmpty ||
        _productImageFile == null ||
        _selectedCategoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields and select an image and category')),
        );
      }
      return;
    }

    try {
      String imageUrl = await _uploadImage(_productImageFile!, 'product');
      await _firestore.collection('products').add({
        'basicInfo': {
          'name': _productNameController.text,
          'description': _productDescriptionController.text,
        },
        'pricing': {'price': double.parse(_productPriceController.text)},
        'media': {'featuredImage': imageUrl},
        'categorization': {'category': _selectedCategoryId},
        'inventory': {'quantity': 100, 'trackQuantity': true},
        'status': {'isActive': true},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _clearProductForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
      }
    } catch (e) {
      print('Error adding product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add product')),
        );
      }
    }
  }

  void _clearCategoryForm() {
    _categoryNameController.clear();
    _categoryDescriptionController.clear();
    if (mounted) {
      setState(() => _categoryImageFile = null);
    }
  }

  void _clearProductForm() {
    _productNameController.clear();
    _productDescriptionController.clear();
    _productPriceController.clear();
    if (mounted) {
      setState(() {
        _productImageFile = null;
        _selectedCategoryId = null;
      });
    }
  }

  void _editProduct(Map<String, dynamic> product) {
    _productNameController.text = product['basicInfo']['name'];
    _productDescriptionController.text = product['basicInfo']['description'] ?? '';
    _productPriceController.text = product['pricing']['price'].toString();
    _selectedCategoryId = product['categorization']['category'];
    if (mounted) {
      setState(() => _productImageFile = null);
    }
  }

  void _editCarouselImage(Map<String, dynamic> image) {
    if (mounted) {
      setState(() {
        _carouselImageFile = null;
        _editingCarouselId = image['id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFFE6FFE6),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Categories Tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _categoryNameController,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _categoryDescriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _pickImage(true),
                  child: const Text('Pick Category Image'),
                ),
                if (_categoryImageFile != null) ...[
                  const SizedBox(height: 10),
                  Image.file(
                    _categoryImageFile!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _addCategory(),
                  child: const Text('Add Category'),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder(
                    stream: _firestore.collection('categories').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final categories = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: category['image'].isNotEmpty
                                  ? CachedNetworkImage(
                                imageUrl: category['image'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              )
                                  : const Icon(Icons.image, size: 50, color: Colors.grey),
                              title: Text(category['name']),
                              subtitle: Text(category['description'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCategory(category.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Products Tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Carousel Section
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
                    autoPlayAnimationDuration: Duration(milliseconds: 800),
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
                              CachedNetworkImage(
                                imageUrl: image['imageUrl'],
                                fit: BoxFit.cover,
                                height: 200,
                                width: MediaQuery.of(context).size.width,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editCarouselImage(image),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteCarouselImage(image['id']),
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
                  onPressed: () => _pickImage(false, isCarousel: true),
                  child: Text(_editingCarouselId != null ? 'Update Carousel Image' : 'Add Carousel Image'),
                ),
                if (_carouselImageFile != null) ...[
                  const SizedBox(height: 10),
                  Image.file(
                    _carouselImageFile!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _editingCarouselId != null
                        ? () => _updateCarouselImage(_editingCarouselId!)
                        : () => _addCarouselImage(),
                    child: Text(_editingCarouselId != null ? 'Save Update' : 'Upload Carousel Image'),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          labelText: 'Search Products',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.search),
                            onPressed: null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _filterOption,
                      hint: const Text('Filter'),
                      items: ['All', 'Price: Low to High', 'Price: High to Low', 'Active', 'Inactive']
                          .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                          .toList(),
                      onChanged: (value) => setState(() => _filterOption = value),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productDescriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productPriceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _pickImage(false),
                  child: const Text('Pick Product Image'),
                ),
                if (_productImageFile != null) ...[
                  const SizedBox(height: 10),
                  Image.file(
                    _productImageFile!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: _selectedCategoryId,
                  hint: const Text('Select Category'),
                  isExpanded: true,
                  items: _categories.map<DropdownMenuItem<String>>((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'],
                      child: Text(category['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (mounted) setState(() => _selectedCategoryId = value);
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _addProduct(),
                  child: const Text('Add Product'),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder(
                    stream: _firestore.collection('products').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      var products = snapshot.data!.docs;
                      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
                        products = products.where((doc) => doc['basicInfo']['name']
                            .toLowerCase()
                            .contains(_searchQuery!.toLowerCase())).toList();
                      }
                      if (_filterOption == 'Price: Low to High') {
                        products.sort((a, b) => a['pricing']['price'].compareTo(b['pricing']['price']));
                      } else if (_filterOption == 'Price: High to Low') {
                        products.sort((a, b) => b['pricing']['price'].compareTo(a['pricing']['price']));
                      } else if (_filterOption == 'Active') {
                        products = products.where((doc) => doc['status']['isActive']).toList();
                      } else if (_filterOption == 'Inactive') {
                        products = products.where((doc) => !doc['status']['isActive']).toList();
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        cacheExtent: 500,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index].data() as Map<String, dynamic>;
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    product['media']['featuredImage'].isNotEmpty
                                        ? CachedNetworkImage(
                                      imageUrl: product['media']['featuredImage'],
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) => const Icon(Icons.image, size: 100, color: Colors.grey),
                                    )
                                        : const Icon(Icons.image, size: 100, color: Colors.grey),
                                    const Positioned(
                                      top: 5,
                                      left: 5,
                                      child: Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Text(
                                          '10%',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  product['basicInfo']['name'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '₹${product['pricing']['price']}',
                                  style: const TextStyle(fontSize: 14, color: Colors.green),
                                ),
                                if (!widget.isAdminMode) ...[
                                  ElevatedButton(
                                    onPressed: product['inventory']['quantity'] > 0
                                        ? () {
                                      // Add to cart logic here
                                    }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(120, 30),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    child: Text(product['inventory']['quantity'] > 0 ? 'Add to Cart' : 'Out of Stock'),
                                  ),
                                ],
                                if (widget.isAdminMode) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _editProduct(product),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteProduct(products[index].id),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
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