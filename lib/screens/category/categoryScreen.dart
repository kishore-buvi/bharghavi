import 'package:bharghavi/screens/rootNavigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';


class CategoryScreen extends StatefulWidget {
  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    _checkAndInitializeCategories().then((_) => _fetchCategories());
  }

  Future<void> _checkAndInitializeCategories() async {
    final snapshot = await _firestore.collection('categories').limit(1).get();
    if (snapshot.docs.isEmpty) {
      await _setupInitialCategories();
    }
  }

  Future<void> _setupInitialCategories() async {
    final categories = [
      // Empty for now; categories will be added via AdminScreen
    ];
    for (var category in categories) {
      try {
        await _firestore.collection('categories').add(category);
      } catch (e) {
        print('Error initializing category: $e');
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final querySnapshot = await _firestore.collection('categories').get();
      setState(() {
        categories = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unnamed Category',
          'image': doc.data()['image'] ?? '',
          'isActive': doc.data()['isActive'] ?? true,
          'description': doc.data()['description'] ?? '',
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    const targetHeight = 1920.0;
    const targetWidth = 1080.0;
    final heightScale = screenHeight / targetHeight;
    final widthScale = screenWidth / targetWidth;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFE6FFE6),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 40 * heightScale,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.business, size: 40 * heightScale, color: Colors.green),
            ),
            SizedBox(width: 10 * widthScale),
            Text(
              'Bhargavi Enterprises',
              style: TextStyle(
                fontSize: 18 * heightScale,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1b622c),
              ),
            ),
          ],
        ),
        actions: [
          // Optional: Add search or other actions if needed
        ],
      ),
      body: Container(
        color: Color(0xFFE6FFE6),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 120 * heightScale),
                  child: Center(
                    child: GridView.builder(
                      padding: EdgeInsets.all(10 * heightScale),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10 * widthScale,
                        mainAxisSpacing: 10 * heightScale,
                      ),
                      itemCount: categories.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        if (!(category['isActive'] ?? true)) return SizedBox.shrink();
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RootNavigation(
                                  categoryId: category['id'],
                                  categoryName: category['name'],
                                ),
                              ),
                            );
                          },
                          child: Card(
                            color: Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10 * heightScale),
                            ),
                            elevation: 4,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                category['image'].isNotEmpty
                                    ? Image.network(
                                  category['image'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.category,
                                        size: 80 * heightScale, color: Colors.yellow);
                                  },
                                )
                                    : Icon(Icons.category, size: 80 * heightScale, color: Colors.yellow),
                                Positioned(
                                  top: 10 * heightScale,
                                  left: 10 * widthScale,
                                  right: 10 * widthScale,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        category['name'] ?? 'Unnamed Category',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 20 * heightScale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              offset: Offset(1 * widthScale, 1 * heightScale),
                                              blurRadius: 3 * heightScale,
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                      ),
                                      Text(
                                        category['description'] ?? 'No Description',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16 * heightScale,
                                          color: Colors.white70,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              offset: Offset(1 * widthScale, 1 * heightScale),
                                              blurRadius: 3 * heightScale,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8 * heightScale),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFFF00),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(10 * heightScale),
                                        bottomRight: Radius.circular(10 * heightScale),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        category['name'] ?? 'Unnamed Category',
                                        style: TextStyle(
                                          fontSize: 14 * heightScale,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}