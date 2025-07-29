import 'package:bharghavi/screens/productList/productCard.dart';
import 'package:bharghavi/screens/productList/productForm.dart';
import 'package:bharghavi/screens/productList/productService.dart';
import 'package:bharghavi/screens/productList/imageService.dart';
import 'package:bharghavi/screens/productList/carouselWidget.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

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
  String? _searchQuery;
  String? _filterOption = 'All';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      products = await _productService.fetchProducts(widget.categoryId);
      carouselImages = await _productService.fetchCarouselImages();
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
          .where((p) => p['name'].toString().toLowerCase().contains(_searchQuery!.toLowerCase()))
          .toList();
    }

    switch (_filterOption) {
      case 'Price: Low to High':
        filteredProducts.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        break;
      case 'Price: High to Low':
        filteredProducts.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
      case 'In Stock':
        filteredProducts = filteredProducts.where((p) => (p['quantity'] ?? 0) > 0).toList();
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
        actions: widget.isAdminMode
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
                  // Carousel Section
                  if (carouselImages.isNotEmpty)
                    SliverToBoxAdapter(
                      child: CarouselWidget(carouselImages: carouselImages),
                    ),

                  // Spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Admin Product Form Section
                  if (widget.isAdminMode)
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
                          onSubmit: (data, image, productId) async {
                            try {
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: ${e.toString()}')),
                                );
                              }
                            }
                          },
                          imageService: _imageService,
                        ),
                      ),
                    ),

                  // Spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Products Grid or Empty State
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
                              isAdminMode: widget.isAdminMode,
                              onEdit: widget.isAdminMode
                                  ? () => _showProductForm(context, product: product)
                                  : () {},
                              onDelete: widget.isAdminMode
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
                                    content: Text('${product['name']} added to cart!'),
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

                  // Bottom spacing
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
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.black87, size: 20),
              onSelected: (value) => setState(() => _filterOption = value),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(value: 'All', child: Text('All Products')),
                const PopupMenuItem(value: 'Price: Low to High', child: Text('Price: Low to High')),
                const PopupMenuItem(value: 'Price: High to Low', child: Text('Price: High to Low')),
                const PopupMenuItem(value: 'In Stock', child: Text('In Stock Only')),
              ],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<Map<String, dynamic>> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          var product = products[index];
          return ProductCard(
            product: product,
            isAdminMode: widget.isAdminMode,
            onEdit: widget.isAdminMode
                ? () => _showProductForm(context, product: product)
                : () {}, // Provide empty function instead of null
            onDelete: widget.isAdminMode
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
                : () {}, // Provide empty function instead of null
            onAddToCart: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product['name']} added to cart!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery != null && _searchQuery!.isNotEmpty
                ? 'No products found for "$_searchQuery"'
                : 'No products available in this category',
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery != null && _searchQuery!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  void _showProductForm(BuildContext context, {Map<String, dynamic>? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: ProductForm(
            product: product,
            onSubmit: (data, image, productId) async {
              try {
                await (productId != null
                    ? _productService.updateProduct(productId, data, image)
                    : _productService.addProduct(widget.categoryId, data, image));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(productId != null ? 'Product updated' : 'Product added')),
                  );
                }
                Navigator.pop(context);
                await _fetchData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            imageService: _imageService,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}