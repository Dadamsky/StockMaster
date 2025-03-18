import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AddProductScreen extends StatefulWidget {
  final Function(String, String, String, String) onProductAdded;

  const AddProductScreen({super.key, required this.onProductAdded});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  String _selectedCategory = "Komputery"; // Domyślna wartość
  String _selectedLocation = "SM-1-1"; // Domyślna wartość
  String _productCode = "Generowanie..."; // Domyślna wartość

  void _addProduct() async {
    final name = _nameController.text;
    final stock = _stockController.text;

    if (name.isNotEmpty && stock.isNotEmpty) {
      final productCode = await FirebaseService().generateProductCode();
      setState(() {
        _productCode = productCode;
      });

      widget.onProductAdded(name, _selectedCategory, stock, _selectedLocation);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj produkt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nazwa produktu'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Kategoria'),
              items: ["Komputery", "Laptopy", "Inne", "Akcesoria"]
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stockController,
              decoration: const InputDecoration(labelText: 'Ilość'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: const InputDecoration(labelText: 'Lokalizacja'),
              items: [
                "SM-1-1", "SM-1-2", "SM-1-3",
                "SM-2-1", "SM-2-2", "SM-2-3",
                "SM-3-1", "SM-3-2", "SM-3-3"
              ].map((location) => DropdownMenuItem(
                    value: location,
                    child: Text(location),
                  ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            Text('Kod Produktu: $_productCode', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addProduct,
              child: const Text('Dodaj produkt'),
            ),
          ],
        ),
      ),
    );
  }
}
