import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  void _showDeliveryDialog(BuildContext context, String productId, String productName,
      String productCode, int currentStock) {
    final TextEditingController qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Dodaj dostawę: $productName'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ilość sztuk'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text);
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wprowadź poprawną ilość')),
                  );
                  return;
                }

                final newStock = currentStock + qty;
                await _firebaseService.updateStock(productId, newStock); 

                final historyCode = await _firebaseService.generateHistoryCode("PM");
                await FirebaseFirestore.instance.collection('history').add({
                  'productId': productId,
                  'code': historyCode,
                  'type': 'PM',
                  'date': Timestamp.now(),
                  'description': 'Dostarczono $qty szt. do produktu $productCode',
                  'quantity': qty.toString(),
                });

                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Zatwierdź'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.search),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Przyjęcie Towaru', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: _getInputDecoration('Szukaj po kodzie produktu (np. SM0005)'),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.trim().toLowerCase();
                });
              },
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Brak produktów'));
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
                    final data = product.data() as Map<String, dynamic>;
                    final productId = product.id;
                    final name = data['name'] ?? '';
                    final productCode = data['productCode'] ?? '';
                    final stock = int.tryParse(data['stock'] ?? '0') ?? 0;
                    final location = data['location'] ?? 'Brak';
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.inventory_2_outlined, color: primaryColor),
                        ),
                        title: Text('$productCode - $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Lokalizacja: $location | Stan: $stock szt.'),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showDeliveryDialog(
                            context,
                            productId,
                            name,
                            productCode,
                            stock,
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('PRZYJMIJ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700, // Zielony akcent dla przyjęcia
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}