import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ProductListScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool isAdminMode;

  ProductListScreen({
    required this.categoryId,
    required this.categoryName,
    this.isAdminMode = false,
  });

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> carouselImages = [];
  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();
  File? _productImageFile;
  String? _searchQuery;
  String? _filterOption = 'All';
  String? _editingProductId;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchCarouselImages();
  }

  Future<void> _fetchProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('categorization.category', isEqualTo: widget.categoryId)
          .where('status.isActive', isEqualTo: true)
          .get();
      setState(() {
        products = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['basicInfo']['name'],
          'price': doc.data()['pricing']['price'],
          'image': doc.data()['media']['featuredImage'] ?? '',
          'quantity': doc.data()['inventory']['quantity'] ?? 0,
          'description': doc.data()['basicInfo']['description'] ?? '',
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching products: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products. Please try again.')),
        );
      }
    }
  }

  Future<void> _fetchCarouselImages() async {
    try {
      final querySnapshot = await _firestore.collection('carousel_images').get();
      setState(() {
        carouselImages = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          'imageUrl': doc.data()['imageUrl'],
          'isActive': doc.data()['isActive'] ?? true,
        }).toList();
      });
    } catch (e) {
      print('Error fetching carousel images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load carousel images.')),
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
      print('Current permission status: $status');

      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      } else {
        final requestStatus = await targetPermission.request();
        print('Requested permission status: $requestStatus');

        if (requestStatus.isGranted) {
          return true;
        } else if (requestStatus.isPermanentlyDenied) {
          _showPermissionDialog();
          return false;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Permission denied. Please allow access to photos.'),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _requestPermissions(),
                ),
              ),
            );
          }
          return false;
        }
      }
    } catch (e) {
      print('Error requesting permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission error. Please try again.')),
        );
      }
      return false;
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text('This app needs access to your photos to upload images. Please enable it in app settings.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) return;

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _productImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image. Please try again.')),
        );
      }
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

  Future<void> _updateProduct(String productId) async {
    if (_productNameController.text.isEmpty || _productPriceController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields')),
        );
      }
      return;
    }

    try {
      String imageUrl = _productImageFile != null
          ? await _uploadImage(_productImageFile!)
          : (await _firestore.collection('products').doc(productId).get()).data()?['media']['featuredImage'] ?? '';
      await _firestore.collection('products').doc(productId).update({
        'basicInfo': {
          'name': _productNameController.text,
          'description': '',
        },
        'pricing': {'price': double.parse(_productPriceController.text)},
        'media': {'featuredImage': imageUrl},
        'inventory': {'quantity': 100},
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _clearProductForm();
      setState(() {
        _editingProductId = null;
      });
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product')),
        );
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product deleted')),
        );
      }
    } catch (e) {
      print('Error deleting product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete product')),
        );
      }
    }
  }

  void _editProduct(Map<String, dynamic> product) {
    _productNameController.text = product['name'];
    _productPriceController.text = product['price'].toString();
    setState(() {
      _productImageFile = null;
      _editingProductId = product['id'];
    });
  }

  void _clearProductForm() {
    _productNameController.clear();
    _productPriceController.clear();
    setState(() {
      _productImageFile = null;
      _editingProductId = null;
    });
  }

  Future<void> _addProduct() async {
    if (_productNameController.text.isEmpty || _productPriceController.text.isEmpty || _productImageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields and select an image')),
        );
      }
      return;
    }

    try {
      String imageUrl = await _uploadImage(_productImageFile!);
      await _firestore.collection('products').add({
        'basicInfo': {
          'name': _productNameController.text,
          'description': '',
        },
        'pricing': {'price': double.parse(_productPriceController.text)},
        'media': {'featuredImage': imageUrl},
        'categorization': {'category': widget.categoryId},
        'inventory': {'quantity': 100},
        'status': {'isActive': true},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _clearProductForm();
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product added successfully')),
        );
      }
    } catch (e) {
      print('Error adding product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    var filteredProducts = List<Map<String, dynamic>>.from(products);

    // Apply search filter
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((p) => p['name'].toString().toLowerCase().contains(_searchQuery!.toLowerCase()))
          .toList();
    }

    // Apply sorting/filtering
    switch (_filterOption) {
      case 'Price: Low to High':
        filteredProducts.sort((a, b) => a['price'].compareTo(b['price']));
        break;
      case 'Price: High to Low':
        filteredProducts.sort((a, b) => b['price'].compareTo(a['price']));
        break;
      case 'In Stock':
        filteredProducts = filteredProducts.where((p) => p['quantity'] > 0).toList();
        break;
      default: // 'All'
        break;
    }

    return filteredProducts;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFE8F5E8),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.categoryName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: widget.isAdminMode
            ? [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: () => _addProduct(),
          ),
        ]
            : null,
      ),
      body: Container(
        color: Color(0xFFE8F5E8),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // Search and Filter Section
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: '',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.menu,
                        color: Colors.black87,
                        size: 20,
                      ),
                      onSelected: (value) => setState(() => _filterOption = value),
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          value: 'All',
                          child: Text('All Products'),
                        ),
                        PopupMenuItem(
                          value: 'Price: Low to High',
                          child: Text('Price: Low to High'),
                        ),
                        PopupMenuItem(
                          value: 'Price: High to Low',
                          child: Text('Price: High to Low'),
                        ),
                        PopupMenuItem(
                          value: 'In Stock',
                          child: Text('In Stock Only'),
                        ),
                      ],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Full Width Carousel
                    Container(
                      width: double.infinity,
                      height: 200,
                      child: carouselImages.isNotEmpty
                          ? CarouselSlider(
                        options: CarouselOptions(
                          height: 200,
                          viewportFraction: 1.0,
                          enlargeCenterPage: false,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                          autoPlayCurve: Curves.fastOutSlowIn,
                          enableInfiniteScroll: true,
                          autoPlayAnimationDuration: Duration(milliseconds: 800),
                        ),
                        items: carouselImages.map((image) {
                          return Builder(
                            builder: (BuildContext context) {
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: Image.network(
                                    image['imageUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Colors.grey[300],
                                      child: Icon(Icons.error, size: 50),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      )
                          : Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Center(
                          child: Text(
                            'No carousel images available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Admin Edit Section (if in admin mode)
                    if (widget.isAdminMode) ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _productNameController,
                              decoration: InputDecoration(
                                labelText: 'Product Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _productPriceController,
                              decoration: InputDecoration(
                                labelText: 'Price',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () => _pickImage(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Pick Product Image'),
                            ),
                            if (_productImageFile != null) ...[
                              SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _productImageFile!,
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                            SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _editingProductId != null
                                  ? () => _updateProduct(_editingProductId!)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Update Product'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                    // Products Grid
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          var product = filteredProducts[index];
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
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '10% OFF',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
                                          '₹${product['price']}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                        Spacer(),
                                        if (widget.isAdminMode) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _editProduct(product),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                    padding: EdgeInsets.symmetric(vertical: 4),
                                                    minimumSize: Size(0, 28),
                                                  ),
                                                  child: Text('Edit', style: TextStyle(fontSize: 10)),
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _deleteProduct(product['id']),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                    padding: EdgeInsets.symmetric(vertical: 4),
                                                    minimumSize: Size(0, 28),
                                                  ),
                                                  child: Text('Delete', style: TextStyle(fontSize: 10)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('${product['name']} added to cart!'),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              },
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
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
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
                    if (filteredProducts.isEmpty)
                      Container(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              _searchQuery != null && _searchQuery!.isNotEmpty
                                  ? 'No products found for "$_searchQuery"'
                                  : 'No products available in this category',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_searchQuery != null && _searchQuery!.isNotEmpty) ...[
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(height: 20), // Reduced spacing since no bottom navigation
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productPriceController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}