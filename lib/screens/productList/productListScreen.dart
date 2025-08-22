import 'package:bharghavi/screens/productList/productCard.dart';
import 'package:bharghavi/screens/productList/productForm.dart';
import 'package:bharghavi/screens/productList/productService.dart';
import 'package:bharghavi/screens/productList/imageService.dart';
import 'package:bharghavi/screens/productList/carouselWidget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductListScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool isAdminMode;

  const ProductListScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    this.isAdminMode = false,
  }) : super(key: key);

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  final ImageService _imageService = ImageService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> carouselImages = [];
  List<Map<String, dynamic>> categories = [];
  String? _searchQuery;
  String? _filterOption = 'All';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchData();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() => _isAdmin = userDoc.exists && userDoc.data()?['role'] == 'admin');
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      products = await _productService.fetchProducts(widget.categoryId) ?? [];
      carouselImages = await _productService.fetchCarouselImages();
      categories = await _productService.fetchCategories() ?? [];
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    var filteredProducts = List<Map<String, dynamic>>.from(products);

    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((p) => (p['basicInfo']?['name']?.toString().toLowerCase() ?? '').contains(_searchQuery!.toLowerCase()))
          .toList();
    }

    switch (_filterOption) {
      case 'Price: Low to High':
        filteredProducts.sort((a, b) => (a['pricing']?['price'] ?? 0).compareTo(b['pricing']?['price'] ?? 0));
        break;
      case 'Price: High to Low':
        filteredProducts.sort((a, b) => (b['pricing']?['price'] ?? 0).compareTo(a['pricing']?['price'] ?? 0));
        break;
      case 'In Stock':
        filteredProducts = filteredProducts.where((p) => (p['inventory']?['quantity'] ?? 0) > 0).toList();
        break;
    }

    return filteredProducts;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: widget.isAdminMode && _isAdmin
            ? [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showProductForm(context),
          ),
        ]
            : null,
      ),
      body: Container(
        color: const Color(0xFFE8F5E8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildSearchAndFilter(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Carousel section using CarouselWidget
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CarouselWidget(carouselImages: carouselImages),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (widget.isAdminMode && _isAdmin)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ProductForm(
                          categories: categories,
                          onSubmit: (data, image, productId, categoryId) async {
                            try {
                              if (FirebaseAuth.instance.currentUser == null) {
                                throw Exception('Please sign in to add products');
                              }
                              await (productId != null
                                  ? _productService.updateProduct(productId, data, image)
                                  : _productService.addProduct(widget.categoryId, data, image));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(productId != null ? 'Product updated' : 'Product added')),
                                );
                              }
                              await _fetchData();
                            } catch (e) {
                              if (mounted) {
                                String errorMessage = e.toString().contains('firebase_storage/unauthorized')
                                    ? 'You do not have permission to add products. Please sign in as an admin.'
                                    : 'Error: ${e.toString()}';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage)),
                                );
                              }
                            }
                          },
                          imageService: _imageService,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (filteredProducts.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            var product = filteredProducts[index];
                            return ProductCard(
                              product: product,
                              isAdminMode: widget.isAdminMode && _isAdmin,
                              onEdit: widget.isAdminMode && _isAdmin
                                  ? () => _showProductForm(context, product: product)
                                  : () {},
                              onDelete: widget.isAdminMode && _isAdmin
                                  ? () async {
                                try {
                                  await _productService.deleteProduct(product['id']);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Product deleted')),
                                    );
                                  }
                                  await _fetchData();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error deleting product: ${e.toString()}')),
                                    );
                                  }
                                }
                              }
                                  : () {},
                              onAddToCart: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${product['basicInfo']?['name'] ?? 'Product'} added to cart!'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: filteredProducts.length,
                        ),
                      ),
                    )
                  else
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white, size: 20),
              onPressed: _showFilterDialog,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery != null && _searchQuery!.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'No products available in this category yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.isAdminMode && _isAdmin) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showProductForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add First Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ...['All', 'Price: Low to High', 'Price: High to Low', 'In Stock'].map(
                    (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _filterOption,
                  onChanged: (value) {
                    setState(() => _filterOption = value);
                    Navigator.pop(context);
                  },
                  activeColor: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showProductForm(BuildContext context, {Map<String, dynamic>? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 20,
                  ),
                  child: ProductForm(
                    categories: categories,
                    product: product,
                    onSubmit: (data, image, productId, categoryId) async {
                      try {
                        if (FirebaseAuth.instance.currentUser == null) {
                          throw Exception('Please sign in to add products');
                        }
                        await (productId != null
                            ? _productService.updateProduct(productId, data, image)
                            : _productService.addProduct(widget.categoryId, data, image));
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(productId != null ? 'Product updated' : 'Product added')),
                          );
                        }
                        await _fetchData();
                      } catch (e) {
                        if (mounted) {
                          String errorMessage = e.toString().contains('firebase_storage/unauthorized')
                              ? 'You do not have permission to add products. Please sign in as an admin.'
                              : 'Error: ${e.toString()}';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessage)),
                          );
                        }
                      }
                    },
                    imageService: _imageService,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}