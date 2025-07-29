  import 'package:bharghavi/admin/productTab/productTab.dart';
  import 'package:flutter/material.dart';
  import 'categoryTab.dart';


  class AdminScreen extends StatefulWidget {
    final bool isAdminMode;

    const AdminScreen({Key? key, this.isAdminMode = true}) : super(key: key);

    @override
    _AdminScreenState createState() => _AdminScreenState();
  }

  class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
    late TabController _tabController;

    @override
    void initState() {
      super.initState();
      _tabController = TabController(length: 2, vsync: this);
    }

    @override
    void dispose() {
      _tabController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          backgroundColor: const Color(0xFFE6FFE6),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Categories'),
              Tab(text: 'Products'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            CategoryTab(),
            ProductTab(),
          ],
        ),
      );
    }
  }