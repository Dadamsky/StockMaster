import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'product_details_screen.dart';
import 'add_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista produktów'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: _firebaseService.getProducts(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Brak produktów w magazynie'));
          }

          final products = snapshot.data!.docs;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final productData = product.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.inventory),
                  title: Text('${productData['productCode']} - ${productData['name']}'),
                  subtitle: Text(
                    'Kategoria: ${productData['category']}\n'
                    'Lokalizacja: ${productData['location']}\n'
                    'Stan: ${productData['stock']} szt.',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _firebaseService.deleteProduct(product.id); // ✅ Poprawione wywołanie deleteProduct()
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsScreen(
                          productId: product.id,
                          name: productData['name'],
                          category: productData['category'],
                          stock: productData['stock'],
                          location: productData['location'],
                          productCode: productData['productCode'],
                          onProductUpdated: _firebaseService.updateProduct,
                          onLocationUpdated: _firebaseService.updateLocation,
                          onProductDeleted: _firebaseService.deleteProduct,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProductScreen(onProductAdded: _firebaseService.addProduct),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}