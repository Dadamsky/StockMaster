import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AddProductScreen extends StatefulWidget {
  final Function(String, String, String, String, String) onProductAdded;

  const AddProductScreen({super.key, required this.onProductAdded});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedCategory = "Inne";
  String _selectedLocation = "SM-1-1";
  bool _isLoading = false;

  // Lista lokalizacji
  final List<String> _locations = [
    "SM-1-1", "SM-1-2", "SM-1-3",
    "SM-2-1", "SM-2-2", "SM-2-3",
    "SM-3-1", "SM-3-2", "SM-3-3"
  ];
  
  // Lista kategorii
  final List<String> _categories = ["Komputery", "Laptopy", "Inne", "Akcesoria", "Telefony"];


  void _addProduct() async {
    final name = _nameController.text;
    final stock = _stockController.text;
    final price = _priceController.text;

    if (name.isEmpty || stock.isEmpty || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola (nazwa, ilość, cena)')),
      );
      return;
    }
    
    setState(() { _isLoading = true; });

    try {
      widget.onProductAdded(
          name, _selectedCategory, stock, _selectedLocation, price);
      
      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e')),
        );
        setState(() { _isLoading = false; });
      }
    }
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodawanie Produktu', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Wprowadź dane nowego produktu', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 25),

              TextField(
                controller: _nameController,
                decoration: _getInputDecoration('Nazwa produktu'),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _getInputDecoration('Kategoria'),
                items: _categories.map((category) => DropdownMenuItem(
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
              const SizedBox(height: 15),

              TextField(
                controller: _stockController,
                decoration: _getInputDecoration('Ilość początkowa'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _priceController,
                decoration: _getInputDecoration('Cena (np. 750.00 zł)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: _selectedLocation,
                decoration: _getInputDecoration('Lokalizacja początkowa'),
                items: _locations.map((location) => DropdownMenuItem(
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
              const SizedBox(height: 40),
              
            
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _addProduct,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, color: Colors.white),
                label: Text(
                  _isLoading ? 'TRWA ZAPIS...' : 'DODAJ PRODUKT',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}