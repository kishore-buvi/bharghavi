// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cached_network_image/cached_network_image.dart';
//
// class CartScreen extends StatefulWidget {
//   const CartScreen({Key? key}) : super(key: key);
//
//   @override
//   _CartScreenState createState() => _CartScreenState();
// }
//
// class _CartScreenState extends State<CartScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   bool isLoading = false;
//   Map<String, dynamic>? cartData;
//   String userId = "current_user_id"; // Replace with actual user ID from auth
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCart();
//   }
//
//   Future<void> _loadCart() async {
//     setState(() => isLoading = true);
//     try {
//       final cartDoc = await _firestore.collection('carts').doc(userId).get();
//       if (cartDoc.exists) {
//         setState(() => cartData = cartDoc.data());
//       }
//     } catch (e) {
//       print('Error loading cart: $e');
//       _showSnackBar('Failed to load cart', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> _updateQuantity(String productId, int newQuantity) async {
//     if (newQuantity <= 0) {
//       await _removeFromCart(productId);
//       return;
//     }
//
//     try {
//       final cartRef = _firestore.collection('carts').doc(userId);
//       final cartDoc = await cartRef.get();
//
//       if (cartDoc.exists) {
//         final data = cartDoc.data()!;
//         List<dynamic> items = List.from(data['items']['products'] ?? []);
//
//         // Find and update the item
//         for (int i = 0; i < items.length; i++) {
//           if (items[i]['productId'] == productId) {
//             items[i]['quantity'] = newQuantity;
//             items[i]['lastModified'] = FieldValue.serverTimestamp();
//             break;
//           }
//         }
//
//         // Recalculate totals
//         double subtotal = items.fold(0.0, (sum, item) =>
//         sum + (item['price'] * item['quantity']));
//
//         await cartRef.update({
//           'items.products': items,
//           'totals.subtotal': subtotal,
//           'totals.total': subtotal,
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//
//         await _loadCart();
//         _showSnackBar('Quantity updated');
//       }
//     } catch (e) {
//       print('Error updating quantity: $e');
//       _showSnackBar('Failed to update quantity', isError: true);
//     }
//   }
//
//   Future<void> _removeFromCart(String productId) async {
//     try {
//       final cartRef = _firestore.collection('carts').doc(userId);
//       final cartDoc = await cartRef.get();
//
//       if (cartDoc.exists) {
//         final data = cartDoc.data()!;
//         List<dynamic> items = List.from(data['items']['products'] ?? []);
//
//         // Remove the item
//         items.removeWhere((item) => item['productId'] == productId);
//
//         if (items.isEmpty) {
//           // Delete the entire cart if empty
//           await cartRef.delete();
//           setState(() => cartData = null);
//         } else {
//           // Recalculate totals
//           double subtotal = items.fold(0.0, (sum, item) =>
//           sum + (item['price'] * item['quantity']));
//
//           await cartRef.update({
//             'items.products': items,
//             'totals.subtotal': subtotal,
//             'totals.total': subtotal,
//             'updatedAt': FieldValue.serverTimestamp(),
//           });
//
//           await _loadCart();
//         }
//
//         _showSnackBar('Item removed from cart');
//       }
//     } catch (e) {
//       print('Error removing from cart: $e');
//       _showSnackBar('Failed to remove item', isError: true);
//     }
//   }
//
//   Future<void> _clearCart() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Clear Cart'),
//         content: const Text('Are you sure you want to remove all items from your cart?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: const Text('Clear', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed == true) {
//       try {
//         await _firestore.collection('carts').doc(userId).delete();
//         setState(() => cartData = null);
//         _showSnackBar('Cart cleared');
//       } catch (e) {
//         print('Error clearing cart: $e');
//         _showSnackBar('Failed to clear cart', isError: true);
//       }
//     }
//   }
//
//   void _showSnackBar(String message, {bool isError = false}) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: isError ? Colors.red : Colors.green,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFE8F5E8),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFFE8F5E8),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: const Text(
//           'My Cart',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//         actions: [
//           if (cartData != null && cartData!['items']['products'].isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.delete_outline, color: Colors.red),
//               onPressed: _clearCart,
//             ),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _buildBody(),
//     );
//   }
//
//   Widget _buildBody() {
//     if (cartData == null || cartData!['items']['products'].isEmpty) {
//       return _buildEmptyCart();
//     }
//
//     final items = cartData!['items']['products'] as List<dynamic>;
//     final totals = cartData!['totals'] as Map<String, dynamic>;
//
//     return Column(
//       children: [
//         Expanded(
//           child: ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: items.length,
//             itemBuilder: (context, index) {
//               final item = items[index];
//               return _buildCartItem(item);
//             },
//           ),
//         ),
//         _buildCartSummary(totals),
//       ],
//     );
//   }
//
//   Widget _buildEmptyCart() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.shopping_cart_outlined,
//             size: 100,
//             color: Colors.grey[400],
//           ),
//           const SizedBox(height: 20),
//           Text(
//             'Your cart is empty',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey[600],
//             ),
//           ),
//           const SizedBox(height: 10),
//           Text(
//             'Add some products to get started!',
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey[500],
//             ),
//           ),
//           const SizedBox(height: 30),
//           ElevatedButton(
//             onPressed: () => Navigator.of(context).pop(),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF2E7D32),
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: const Text('Continue Shopping'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCartItem(Map<String, dynamic> item) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Product Image
//           ClipRRect(
//             borderRadius: BorderRadius.circular(8),
//             child: CachedNetworkImage(
//               imageUrl: item['image'] ?? '',
//               width: 80,
//               height: 80,
//               fit: BoxFit.cover,
//               placeholder: (context, url) => Container(
//                 width: 80,
//                 height: 80,
//                 color: Colors.grey[200],
//                 child: const Center(child: CircularProgressIndicator()),
//               ),
//               errorWidget: (context, url, error) => Container(
//                 width: 80,
//                 height: 80,
//                 color: Colors.grey[200],
//                 child: Icon(Icons.image, color: Colors.grey[400]),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//
//           // Product Details
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   item['name'] ?? 'Product Name',
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   '₹${item['price']}',
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2E7D32),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//
//                 // Quantity Controls
//                 Row(
//                   children: [
//                     Container(
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey[300]!),
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           InkWell(
//                             onTap: () => _updateQuantity(
//                               item['productId'],
//                               item['quantity'] - 1,
//                             ),
//                             child: Container(
//                               padding: const EdgeInsets.all(6),
//                               child: const Icon(Icons.remove, size: 16),
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                             child: Text(
//                               '${item['quantity']}',
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           InkWell(
//                             onTap: () => _updateQuantity(
//                               item['productId'],
//                               item['quantity'] + 1,
//                             ),
//                             child: Container(
//                               padding: const EdgeInsets.all(6),
//                               child: const Icon(Icons.add, size: 16),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const Spacer(),
//
//                     // Remove Button
//                     InkWell(
//                       onTap: () => _removeFromCart(item['productId']),
//                       child: Container(
//                         padding: const EdgeInsets.all(6),
//                         decoration: BoxDecoration(
//                           color: Colors.red[50],
//                           borderRadius: BorderRadius.circular(6),
//                         ),
//                         child: const Icon(
//                           Icons.delete_outline,
//                           color: Colors.red,
//                           size: 20,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCartSummary(Map<String, dynamic> totals) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Order Summary
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Subtotal:',
//                 style: TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//               Text(
//                 '₹${totals['subtotal']?.toStringAsFixed(2) ?? '0.00'}',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Delivery:',
//                 style: TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//               Text(
//                 totals['shipping'] == 0 ? 'Free' : '₹${totals['shipping']?.toStringAsFixed(2) ?? '0.00'}',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: totals['shipping'] == 0 ? Colors.green : Colors.black,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           const Divider(),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Total:',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               Text(
//                 '₹${totals['total']?.toStringAsFixed(2) ?? '0.00'}',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF2E7D32),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//
//           // Checkout Button
//           SizedBox(
//             width: double.infinity,
//             height: 50,
//             child: ElevatedButton(
//               onPressed: () {
//                 // Navigate to checkout screen
//                 Navigator.pushNamed(context, '/checkout');
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFFFFCF50),
//                 foregroundColor: Colors.black87,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 0,
//               ),
//               child: const Text(
//                 'PROCEED TO CHECKOUT',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }