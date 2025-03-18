import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'location_picker_dialog.dart';
class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  final String name;
  final String category;
  final String stock;
  final String location;
  final String productCode;
  final Function(String, String, String) onProductUpdated;
  final Function(String, String) onLocationUpdated;
  final Function(String) onProductDeleted;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    required this.name,
    required this.category,
    required this.stock,
    required this.location,
    required this.productCode,
    required this.onProductUpdated,
    required this.onLocationUpdated,
    required this.onProductDeleted,
  });

  @override
  _ProductDetailsScreenState createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  String _selectedLocation = "";
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _stockController = TextEditingController(text: widget.stock);
    _selectedLocation = widget.location;
  }

  void _changeLocation() async {
    String? newLocation = await showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(initialLocation: _selectedLocation),
    );

    if (newLocation != null) {
      setState(() {
        _selectedLocation = newLocation;
      });
      widget.onLocationUpdated(widget.productId, newLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szczegóły produktu')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nazwa produktu'),
            ),
            TextField(
              controller: _stockController,
              decoration: const InputDecoration(labelText: 'Ilość'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Text('Kod Produktu: ${widget.productCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lokalizacja: $_selectedLocation', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _changeLocation,
                  child: const Text('Przesunięcie'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Historia:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
  child: StreamBuilder(
    stream: _firebaseService.getProductHistory(widget.productId),
    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(child: Text('Brak historii dla tego produktu'));
      }

      final history = snapshot.data!.docs;

      return ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          final data = entry.data() as Map<String, dynamic>;

          return ListTile(
            title: Text('${data['code']} - ${data['description']}'),
            subtitle: Text('Data: ${(data['date'] as Timestamp).toDate()}'),
          );
        },
      );
    },
  ),
),
          ],
        ),
      ),
    );
  }
}
