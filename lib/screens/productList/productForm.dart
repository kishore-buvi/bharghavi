import 'dart:io';
import 'package:flutter/material.dart';
import 'imageService.dart';

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  final List<Map<String, dynamic>> categories;
  final Function(Map<String, dynamic>, File?, String?, String?) onSubmit;
  final ImageService imageService;

  const ProductForm({
    Key? key,
    this.product,
    required this.categories,
    required this.onSubmit,
    required this.imageService,
  }) : super(key: key);

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController(text: 'Bhargavi Oil Store');
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productQuantityController = TextEditingController();
  final _productDiscountController = TextEditingController();
  File? _productImageFile;
  String? _selectedCategoryId;
  String? _editingProductId;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final fullName = widget.product!['basicInfo']['name'] ?? '';
      if (fullName.contains(' - ')) {
        final parts = fullName.split(' - ');
        _storeNameController.text = parts[0];
        _productNameController.text = parts.length > 1 ? parts[1] : '';
      } else {
        _productNameController.text = fullName;
      }
      _productDescriptionController.text = widget.product!['basicInfo']['description'] ?? '';
      _productPriceController.text = widget.product!['pricing']['price']?.toString() ?? '';
      _productQuantityController.text = widget.product!['inventory']['quantity']?.toString() ?? '';
      _productDiscountController.text = widget.product!['discount']['percentage']?.toString() ?? '';
      _selectedCategoryId = widget.product!['categorization']['category'];
      _editingProductId = widget.product!['id'];
    }
  }

  void _clearForm() {
    _storeNameController.text = 'Bhargavi Oil Store';
    _productNameController.clear();
    _productDescriptionController.clear();
    _productPriceController.clear();
    _productQuantityController.clear();
    _productDiscountController.clear();
    setState(() {
      _productImageFile = null;
      _selectedCategoryId = null;
    });
  }

  String? _validateNumeric(String? value, String field) {
    if (value == null || value.isEmpty) return 'Please enter $field';
    final numValue = double.tryParse(value);
    if (numValue == null) return 'Please enter a valid number for $field';
    if (numValue < 0) return '$field cannot be negative';
    return null;
  }

  String? _validateProductName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a product name';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: _validateProductName,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productPriceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                ),
                keyboardType: TextInputType.number,
                validator: (value) => _validateNumeric(value, 'price'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => _validateNumeric(value, 'quantity'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productDiscountController,
                decoration: const InputDecoration(
                  labelText: 'Discount %',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                validator: (value) => _validateNumeric(value, 'discount'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                hint: const Text('Select Category'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: widget.categories.map((category) => DropdownMenuItem<String>(
                  value: category['id'],
                  child: Text(category['name']),
                )).toList(),
                onChanged: (value) => setState(() => _selectedCategoryId = value),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  _productImageFile = await widget.imageService.pickImage(context);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text('Pick Product Image'),
              ),
              if (_productImageFile != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_productImageFile!, height: 100, width: 100, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_productImageFile == null && _editingProductId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an image')),
                      );
                      return;
                    }
                    widget.onSubmit(
                      {
                        'name': '${_storeNameController.text} - ${_productNameController.text}',
                        'description': _productDescriptionController.text,
                        'price': _productPriceController.text,
                        'quantity': _productQuantityController.text,
                        'discount': _productDiscountController.text,
                      },
                      _productImageFile,
                      _editingProductId,
                      _selectedCategoryId,
                    );
                    _clearForm();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: Text(_editingProductId != null ? 'Update Product' : 'Add Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productQuantityController.dispose();
    _productDiscountController.dispose();
    super.dispose();
  }
}