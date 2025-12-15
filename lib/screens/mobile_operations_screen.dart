import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stockmaster/services/firebase_service.dart'; 
import 'screen_scanner.dart'; 
import 'new_issue_screen.dart'; 
import 'product_details_screen.dart'; 
import 'location_picker_dialog.dart';

class MobileOperationsScreen extends StatefulWidget {
  const MobileOperationsScreen({super.key});

  @override
  State<MobileOperationsScreen> createState() => _MobileOperationsScreenState();
}

class _MobileOperationsScreenState extends State<MobileOperationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // --- FUNKCJE POMOCNICZE UI ---

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  /// 1. PRZYJMIJ TOWAR
  Future<void> _scanAndReceiveProduct() async {
    final String? scannedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedBarcode == null || scannedBarcode.isEmpty || !mounted) {
      return;
    }
    
    await Future.delayed(const Duration(milliseconds: 100)); 

    final productDoc = await _firebaseService.getProductByBarcode(scannedBarcode);

    if (productDoc == null) {
      _showErrorSnackbar('Nie znaleziono produktu o kodzie: $scannedBarcode');
      return;
    }

    final data = productDoc.data() as Map<String, dynamic>;
    final productId = productDoc.id;
    final name = data['name'] ?? 'Brak nazwy';
    final productCode = data['productCode'] ?? '';
    final stock = int.tryParse(data['stock'] ?? '0') ?? 0;
    final location = data['location'] ?? 'Brak';

    if (mounted) {
      _showReceiveDialog(context, productId, name, productCode, stock, location);
    }
  }

  /// 2. WYDAJ TOWAR
  void _startIssueProcess() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewIssueScreen()),
    );
  }

  /// 3. ZMIEŃ LOKALIZACJĘ
  Future<void> _scanAndChangeLocation() async {
    final String? scannedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedBarcode == null || scannedBarcode.isEmpty || !mounted) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 100));
    final productDoc = await _firebaseService.getProductByBarcode(scannedBarcode);

    if (productDoc == null) {
      _showErrorSnackbar('Nie znaleziono produktu o kodzie: $scannedBarcode');
      return;
    }

    final data = productDoc.data() as Map<String, dynamic>;
    final currentLocation = data['location'] ?? 'Brak';

    String? newLocation = await showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(initialLocation: currentLocation),
    );

    if (newLocation != null && newLocation != currentLocation) {
      await _firebaseService.updateLocation(productDoc.id, newLocation);
      
      _showSuccessSnackbar('Produkt ${data['productCode']} przeniesiono do: $newLocation');
    } else if (newLocation != null) {
      _showErrorSnackbar('Lokalizacja nie została zmieniona.');
    }
  }

  /// 4. SPRAWDŹ PRODUKT
  Future<void> _scanAndCheckProduct() async {
    final String? scannedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedBarcode == null || scannedBarcode.isEmpty || !mounted) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 100));
    final productDoc = await _firebaseService.getProductByBarcode(scannedBarcode);

    if (productDoc == null) {
      _showErrorSnackbar('Nie znaleziono produktu o kodzie: $scannedBarcode');
      return;
    }

    final data = productDoc.data() as Map<String, dynamic>;
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailsScreen(
            productId: productDoc.id,
            name: data['name'] ?? 'Brak',
            category: data['category'] ?? 'Brak',
            stock: data['stock'] ?? '0',
            location: data['location'] ?? 'Brak',
            productCode: data['productCode'] ?? 'Brak',
            price: data['price'] ?? '0.00', 
            onProductUpdated: _firebaseService.updateProduct,
            onLocationUpdated: _firebaseService.updateLocation,
            onProductDeleted: _firebaseService.deleteProduct,
          ),
        ),
      );
    }
  }
  
  /// OKNO DIALOGOWE PRZYJĘCIA - Wyświetlany po skanowaniu etykiety
  void _showReceiveDialog(BuildContext context, String productId,
      String productName, String productCode, int currentStock, String initialLocation) {
    final TextEditingController qtyController = TextEditingController();
    
    final List<String> predefinedLocations = [
      "SM-1-1", "SM-1-2", "SM-1-3",
      "SM-2-1", "SM-2-2", "SM-2-3",
      "SM-3-1", "SM-3-2", "SM-3-3"
    ];
    
    final Set<String> uniqueLocations = {initialLocation, ...predefinedLocations};
    final List<String> locations = uniqueLocations.toList()..sort(); 
    String selectedLocation = initialLocation;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Przyjmij: $productName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kod: $productCode'),
                  Text('Obecny stan: $currentStock szt.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ilość do przyjęcia'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLocation,
                    decoration: const InputDecoration(labelText: 'Lokalizacja docelowa'),
                    items: locations.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(loc),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedLocation = value;
                        });
                      }
                    },
                  ),
                ],
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
                      _showErrorSnackbar('Wprowadź poprawną ilość');
                      return;
                    }

                    final newStock = currentStock + qty;
                    await _firebaseService.updateStockAndLocation(
                        productId, newStock, selectedLocation);

                    final historyCode = await _firebaseService.generateHistoryCode("PM");
                    await FirebaseFirestore.instance.collection('history').add({
                      'productId': productId,
                      'code': historyCode,
                      'type': 'PM',
                      'date': Timestamp.now(),
                      'description': 'Dostarczono $qty szt. do $productCode na $selectedLocation',
                      'quantity': qty.toString(), 
                    });

                    _showSuccessSnackbar('Przyjęcie $qty szt. do $productCode zatwierdzone!');
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Zatwierdź'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- WIDŻET GŁÓWNY ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobilne Operacje', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wybierz operację mobilną', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0, 
              children: [
                // 1. PRZYJMIJ TOWAR (PM)
                _buildOperationCard(
                  context,
                  'Przyjmij Towar',
                  Icons.inventory_2_outlined,
                  const Color(0xFF0D47A1),
                  _scanAndReceiveProduct,
                ),
                
                // 2. WYDAJ TOWAR (SP - Kompletacja Koszyka)
                _buildOperationCard(
                  context,
                  'Wydaj Towar',
                  Icons.output_rounded,
                  const Color(0xFFC62828),
                  _startIssueProcess, 
                ),

                // 3. ZMIEŃ LOKALIZACJĘ (MM)
                _buildOperationCard(
                  context,
                  'Zmień Lokalizację',
                  Icons.swap_horiz_rounded,
                  const Color(0xFF2E7D32),
                  _scanAndChangeLocation, 
                ),

                // 4. SPRAWDŹ PRODUKT (INFO)
                _buildOperationCard(
                  context,
                  'Sprawdź Produkt',
                  Icons.search_rounded,
                  const Color(0xFF424242),
                  _scanAndCheckProduct, 
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOperationCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: color.withOpacity(0.5), width: 1.5), 
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: color),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
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