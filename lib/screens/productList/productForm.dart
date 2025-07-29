import 'dart:io';
import 'package:flutter/material.dart';
import 'imageService.dart'; // Adjust the import path based on your project structure

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  final Function(Map<String, dynamic>, File?, String?) onSubmit;
  final ImageService imageService;

  ProductForm({this.product, required this.onSubmit, required this.imageService});

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController(text: 'Bhargavi Oil Store ');
  final _productPriceController = TextEditingController();
  final _productQuantityController = TextEditingController();
  final _productDiscountController = TextEditingController();
  File? _productImageFile;
  String? _editingProductId;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _productNameController.text = widget.product!['name'];
      _productPriceController.text = widget.product!['price'].toString();
      _productQuantityController.text = widget.product!['quantity'].toString();
      _productDiscountController.text = widget.product!['discount'].toString();
      _editingProductId = widget.product!['id'];
    }
  }

  void _clearForm() {
    _productNameController.text = 'Bhargavi Oil Store ';
    _productPriceController.clear();
    _productQuantityController.clear();
    _productDiscountController.clear();
    setState(() => _productImageFile = null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a product name' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _productPriceController,
                decoration: InputDecoration(labelText: 'Price', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _productQuantityController,
                decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a quantity' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _productDiscountController,
                decoration: InputDecoration(labelText: 'Discount %', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a discount' : null,
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  _productImageFile = await widget.imageService.pickImage(context);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: Text('Pick Product Image'),
              ),
              if (_productImageFile != null) ...[
                SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_productImageFile!, height: 100, width: 100, fit: BoxFit.cover),
                ),
              ],
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_productImageFile == null && _editingProductId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select an image')),
                      );
                      return;
                    }
                    widget.onSubmit({
                      'name': _productNameController.text,
                      'price': _productPriceController.text,
                      'quantity': _productQuantityController.text,
                      'discount': _productDiscountController.text,
                    }, _productImageFile, _editingProductId);
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
    _productNameController.dispose();
    _productPriceController.dispose();
    _productQuantityController.dispose();
    _productDiscountController.dispose();
    super.dispose();
  }
}