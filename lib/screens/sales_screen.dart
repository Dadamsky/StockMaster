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

  Future<void> _searchProduct() async {
    setState(() {
      _isLoading = true;
      _product = null;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('productCode', isEqualTo: _codeController.text.trim())
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _product = snapshot.docs.first.data();
        _product!['id'] = snapshot.docs.first.id;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produkt nie znaleziony')),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _processSale() async {
    if (_product == null) return;
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wprowadź poprawną ilość')),
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
});


    // Generowanie paragonu/faktury
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

  Future<void> _generateInvoice(int quantity) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Faktura VAT', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 16),
              pw.Text('Data: ${DateTime.now().toLocal()}'),
              pw.Text('Numer faktury: FV-${DateTime.now().millisecondsSinceEpoch}'),
              pw.SizedBox(height: 32),
              pw.Text('Sprzedawca:'),
              pw.Text('Firma XYZ'),
              pw.Text('ul. Przykladowa 1'),
              pw.Text('00-000 Miasto'),
              pw.SizedBox(height: 16),
              pw.Text('Nabywca:'),
              pw.Text('Klient indywidualny'),
              pw.SizedBox(height: 32),
              pw.TableHelper.fromTextArray(
                headers: ['Kod', 'Nazwa', 'Ilosc'],
                data: [
                  [_product!['productCode'], _product!['name'], quantity.toString()],
                ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprzedaż produktu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Kod produktu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _searchProduct,
              child: const Text('Szukaj produktu'),
            ),
            const SizedBox(height: 16),
            if (_product != null) ...[
              Text('Nazwa: ${_product!['name']}'),
              Text('Stan magazynowy: ${_product!['stock']}'),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Ilość do sprzedaży',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _processSale,
                child: const Text('Sprzedaj'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
