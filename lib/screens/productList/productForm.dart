import 'dart:io';
import 'package:flutter/material.dart';
import 'imageService.dart';

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  final Function(Map<String, dynamic>, File?, String?) onSubmit;
  final ImageService imageService;
  final List<Map<String, dynamic>> categories;

  const ProductForm({
    Key? key,
    this.product,
    required this.onSubmit,
    required this.imageService,
    required this.categories,
  }) : super(key: key);

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productQuantityController = TextEditingController();
  final _productDiscountController = TextEditingController();
  String? _selectedCategoryId;
  File? _productImageFile;
  String? _editingProductId;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _productNameController.text = widget.product!['basicInfo']['name'] ?? '';
      _productDescriptionController.text = widget.product!['basicInfo']['description'] ?? '';
      _productPriceController.text = widget.product!['pricing']['price']?.toString() ?? '';
      _productQuantityController.text = widget.product!['inventory']['quantity']?.toString() ?? '';
      _productDiscountController.text = widget.product!['discount']['percentage']?.toString() ?? '0';
      _selectedCategoryId = widget.product!['categorization']['category'];
      _editingProductId = widget.product!['id'];
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
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
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Please enter a product name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                value != null && value.trim().length > 200 ? 'Description must be less than 200 characters' : null,
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a price';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _productQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a quantity';
                  if (int.tryParse(value) == null || int.parse(value) < 0) return 'Enter a valid quantity';
                  return null;
                },
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a discount';
                  if (double.tryParse(value) == null || double.parse(value) < 0) return 'Enter a valid discount';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                hint: const Text('Select Category'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map((category) => DropdownMenuItem<String>(
                  value: category['id'],
                  child: Text(category['name']),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategoryId = value),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  _productImageFile = await widget.imageService.pickImage(context);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Pick Product Image'),
              ),
              if (_productImageFile != null) ...[
                const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          if (_productImageFile == null && _editingProductId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an image')),
                            );
                            return;
                          }
                          widget.onSubmit({
                            'name': _productNameController.text.trim(),
                            'description': _productDescriptionController.text.trim(),
                            'price': _productPriceController.text,
                            'quantity': _productQuantityController.text,
                            'discount': _productDiscountController.text,
                            'categoryId': _selectedCategoryId,
                          }, _productImageFile, _editingProductId);
                          _clearForm();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_editingProductId != null ? 'Update Product' : 'Add Product'),
                    ),
                  ),
                  if (_editingProductId != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _clearForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productQuantityController.dispose();
    _productDiscountController.dispose();
    super.dispose();
  }
}