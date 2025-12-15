import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/firebase_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  Map<String, dynamic>? _product;
  bool _isLoading = false;

  /// Wyszukuje produkt w bazie na podstawie kodu
  Future<void> _searchProduct() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _product = null;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('productCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _product = snapshot.docs.first.data();
        _product!['id'] = snapshot.docs.first.id;
        _product!['price'] = _product!['price'] ?? '0.00'; // Upewniamy się, że cena jest
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produkt o kodzie $code nie znaleziony')),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  /// Przetwarza sprzedaż i waliduje stany
  Future<void> _processSale() async {
    if (_product == null) return;
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wprowadź poprawną ilość do sprzedaży')),
      );
      return;
    }
    final currentStock = int.tryParse(_product!['stock'].toString()) ?? 0;
    if (quantity > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak wystarczającej ilości w magazynie')),
      );
      return;
    }

    // Aktualizacja stanu magazynowego
    final newStock = currentStock - quantity;
    // NOTE: Używamy starej funkcji updateProduct, która aktualizuje tylko nazwę i stan
    await _firebaseService.updateProduct(_product!['id'], _product!['name'], newStock.toString());

    // Dodanie wpisu do historii
    final historyCode = await _firebaseService.generateHistoryCode("SP");
    await FirebaseFirestore.instance
        .collection('history')
        .add({
      'productId': _product!['id'],
      'code': historyCode,
      'type': 'SP',
      'date': Timestamp.now(),
      'description': 'Sprzedaż $quantity szt. z produktu ${_product!['productCode']}',
      'quantity': quantity.toString(),
    });

    // Generowanie paragonu (używamy uproszczonej wersji bez dialogu wyboru)
    await _generateInvoice(quantity);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sprzedaż zakończona pomyślnie')),
    );

    setState(() {
      _product = null;
      _codeController.clear();
      _quantityController.clear();
    });
  }

  /// Uproszczona funkcja generująca fakturę/paragon (bez pełnej logiki VAT)
  Future<void> _generateInvoice(int quantity) async {
    final pdf = pw.Document();
    final totalPrice = quantity * (double.tryParse(_product!['price'].toString()) ?? 0.0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PARAGON/FAKTURA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Sprzedawca: StockMaster Sp. z o. o.'),
              pw.SizedBox(height: 16),
              pw.Text('Data: ${DateTime.now().toLocal()}'),
              pw.SizedBox(height: 32),
              
              pw.Text('Pozycja:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(
                headers: ['Kod', 'Nazwa', 'Cena jedn.', 'Ilosc', 'Suma Brutto'],
                data: [
                  [
                    _product!['productCode'], 
                    _product!['name'], 
                    '${_product!['price']} zł',
                    quantity.toString(),
                    '${totalPrice.toStringAsFixed(2)} zł',
                  ],
                ],
                cellAlignment: pw.Alignment.centerRight,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerAlignment: pw.Alignment.centerRight,
              ),
              
              pw.SizedBox(height: 32),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('DO ZAPŁATY: ${totalPrice.toStringAsFixed(2)} zł', 
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              
              pw.SizedBox(height: 32),
              pw.Text('Dziekujemy za zakupy!'),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final successColor = Colors.green.shade600;
    final failureColor = Colors.red.shade600;
    
    // Status koloru karty (jeśli produkt znaleziony)
    Color statusColor = Colors.grey.shade300;
    if (_product != null) {
        final currentStock = int.tryParse(_product!['stock'].toString()) ?? 0;
        statusColor = currentStock > 0 ? successColor.withOpacity(0.1) : failureColor.withOpacity(0.1);
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprzedaż produktu', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600), // Ograniczenie szerokości na tabletach
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. SEKCJA WYSZUKIWANIA ---
              Text(
                'Wyszukaj po kodzie',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: 'Kod produktu',
                        hintText: 'Np. SM0005',
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _searchProduct(), // Szukaj po Enter
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56, // Dopasowujemy wysokość do pola tekstowego
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _searchProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Szukaj'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              
              // --- 2. KARTA WYNIKÓW I PROCES SPRZEDAŻY ---
              if (_product != null) 
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: statusColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _product!['name'] ?? 'Brak nazwy',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: currentStock > 0 ? successColor : failureColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                currentStock > 0 ? 'NA STANIE' : 'BRAK',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Kod: ${_product!['productCode']}', style: TextStyle(color: Colors.grey.shade700)),
                        Text('Lokalizacja: ${_product!['location']}', style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 15),
                        Text(
                          'Cena: ${_product!['price']} zł',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: successColor),
                        ),
                        
                        const Divider(height: 30),

                        // Input ilości
                        TextField(
                          controller: _quantityController,
                          decoration: InputDecoration(
                            labelText: 'Ilość do sprzedaży',
                            hintText: 'Maks. $currentStock szt.',
                            prefixIcon: const Icon(Icons.exposure),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),
                        
                        // Przycisk Sprzedaj
                        ElevatedButton.icon(
                          onPressed: currentStock > 0 ? _processSale : null, // Nie można sprzedać, gdy stan < 1
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: Text(
                            currentStock > 0 ? 'ZATWIERDŹ SPRZEDAŻ' : 'BRAK TOWARU',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentStock > 0 ? successColor : failureColor.withOpacity(0.5),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Jeśli nie znaleziono produktu
              if (_product == null && !_isLoading)
                 Padding(
                   padding: const EdgeInsets.only(top: 50.0),
                   child: Center(
                     child: Text(
                       'Wyszukaj produkt po kodzie, aby rozpocząć transakcję.',
                       style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                       textAlign: TextAlign.center,
                     ),
                   ),
                 ),

              if (_isLoading)
                 const Padding(
                   padding: EdgeInsets.only(top: 50.0),
                   child: Center(child: CircularProgressIndicator()),
                 ),

            ],
          ),
        ),
      ),
    );
  }

  // --- GETTERY POMOCNICZE (aby kod w build był czystszy) ---
  int get currentStock => int.tryParse(_product!['stock'].toString()) ?? 0;
}