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
    final TextEditingController _qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Dodaj dostawę: $productName'),
          content: TextField(
            controller: _qtyController,
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
                final qty = int.tryParse(_qtyController.text);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dostawy'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Szukaj po kodzie produktu (np. SM0005)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
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

                    return ListTile(
                      title: Text('$productCode - $name'),
                      subtitle: Text('Stan: $stock szt.'),
                      trailing: ElevatedButton(
                        onPressed: () => _showDeliveryDialog(
                          context,
                          productId,
                          name,
                          productCode,
                          stock,
                        ),
                        child: const Text('Dodaj dostawę'),
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
