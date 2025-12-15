import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'product_details_screen.dart';
import 'add_product_screen.dart';
import 'sales_screen.dart'; // Używamy tego do nawigacji, choć docelowo to będzie NewIssueScreen

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produkty w Magazynie', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        actions: [
          // Przenosimy ikonę sprzedaży do body, ale zostawiamy miejsce na wylogowanie/inne akcje
        ],
      ),
      body: Column(
        children: [
          // --- 1. KARTA/PRZYCISK SPRZEDAŻY ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Docelowo tutaj nawigujemy do ekranu sprzedaży (NewIssueScreen)
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SalesScreen()),
                      );
                    },
                    icon: const Icon(Icons.point_of_sale_outlined, size: 24),
                    label: const Text(
                      'ROZPOCZNIJ SPRZEDAŻ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // --- 2. WYPEŁNIONE POLE WYSZUKIWANIA ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Szukaj po kodzie produktu',
                prefixIcon: const Icon(Icons.search),
                filled: true, // Wypełnione tło
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.trim().toLowerCase();
                });
              },
            ),
          ),

          // --- 3. LISTA PRODUKTÓW ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getProducts(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Brak produktów w magazynie'));
                }

                final products = snapshot.data!.docs;
                final filteredProducts = products.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final code = (data['productCode'] ?? '').toString().toLowerCase();
                  return code.contains(_searchTerm);
                }).toList();

                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final productData = product.data() as Map<String, dynamic>;

                    final price = productData['price'] ?? '0.00';
                    final stock = productData['stock'] ?? '0';
                    final category = productData['category'] ?? 'Brak';
                    final location = productData['location'] ?? 'Brak';
                    final name = productData['name'] ?? 'Brak nazwy';
                    final productCode = productData['productCode'] ?? 'Brak kodu';
                    
                    return Card(
                      elevation: 1, // Mniejszy cień na liście
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.inventory, color: primaryColor),
                        ),
                        title: Text('$productCode - $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          // Nowy, bardziej skondensowany podtytuł
                          'Kategoria: $category | Lokalizacja: $location\n'
                          'Stan: $stock szt. | Cena: $price zł',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            _firebaseService.deleteProduct(product.id);
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailsScreen(
                                productId: product.id,
                                name: name,
                                category: category,
                                stock: stock,
                                location: location,
                                productCode: productCode,
                                price: price, 
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddProductScreen(onProductAdded: _firebaseService.addProduct),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Dodaj nowy produkt'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}