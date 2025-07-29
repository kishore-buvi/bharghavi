import 'package:bharghavi/screens/favourites/favouritesScreen.dart';
import 'package:bharghavi/screens/productList/productListScreen.dart';
import 'package:bharghavi/screens/profile/profileScreen.dart';
import 'package:bharghavi/screens/cart/cartScreen.dart';
import 'package:flutter/material.dart';
import '../widget/curvedBottomNavigationBar.dart';

class RootNavigation extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const RootNavigation({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  _RootNavigationState createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProductListScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        isAdminMode: false,
      ),
       FavoritesScreen(),
       ProfileScreen(),
       CartScreen(),
    ];
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: CurvedBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        icons: const [
          Icons.home,
          Icons.favorite,
          Icons.person,
          Icons.shopping_cart,
        ],
        backgroundColor: const Color(0xFF2E7D32),
        selectedColor: Colors.white,
        unselectedColor: Colors.white,
      ),
    );
  }
}