import 'package:flutter/material.dart';

class CartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Favorites"),
        leading: BackButton(),
      ),
      body: Center(
        child: Text("Your favorite items will appear here."),
      ),
    );
  }
}
