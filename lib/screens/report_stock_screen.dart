import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';

class ReportStockScreen extends StatefulWidget {
  const ReportStockScreen({super.key});

  @override
  State<ReportStockScreen> createState() => _ReportStockScreenState();
}

class _ReportStockScreenState extends State<ReportStockScreen> {
  final CollectionReference _products = FirebaseFirestore.instance.collection('products');

  // Funkcja generująca PDF
  Future<void> _generatePdf(List<QueryDocumentSnapshot> products) async {
    final pdf = pw.Document();
    
    // Obliczanie całkowitej wartości (zakładając cenę jako String do parsowania)
    double totalValue = 0;
    for (var doc in products) {
      final data = doc.data() as Map<String, dynamic>;
      final stock = double.tryParse(data['stock'] ?? '0') ?? 0.0;
      final price = double.tryParse(data['price'] ?? '0.0') ?? 0.0;
      totalValue += stock * price;
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Raport stanów magazynowych', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Całkowita wartość zapasów: ${totalValue.toStringAsFixed(2)} zł', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Kod', 'Nazwa', 'Kategoria', 'Stan', 'Cena (zł)'],
                data: products.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return [
                    data['productCode'] ?? '',
                    data['name'] ?? '',
                    data['category'] ?? '',
                    data['stock'] ?? '',
                    (data['price'] ?? '0.00').toString(), // Dodano cenę
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // Funkcja generująca CSV
  Future<void> _generateCsv(List<QueryDocumentSnapshot> products) async {
    final List<List<String>> rows = [
      ['Kod', 'Nazwa', 'Kategoria', 'Lokalizacja', 'Stan', 'Cena (zł)'] // Dodano cenę
    ];

    for (var doc in products) {
      final data = doc.data() as Map<String, dynamic>;
      rows.add([
        data['productCode'] ?? '',
        data['name'] ?? '',
        data['category'] ?? '',
        data['location'] ?? '',
        data['stock'] ?? '',
        data['price'] ?? '0.00', // Dodano cenę
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await Printing.sharePdf(bytes: bytes, filename: 'raport_stanow.csv');
  }
  
  // Funkcja pomocnicza do budowania przycisków eksportu
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        elevation: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raport Stanów Magazynowych', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _products.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final products = snapshot.data!.docs;
          
          // Obliczanie statystyk
          double totalValue = 0;
          int totalStock = 0;
          
          for (var doc in products) {
            final data = doc.data() as Map<String, dynamic>;
            final stock = int.tryParse(data['stock'] ?? '0') ?? 0;
            final price = double.tryParse(data['price'] ?? '0.0') ?? 0.0;
            
            totalStock += stock;
            totalValue += stock * price;
          }


          return Column(
            children: [
              // --- 1. SEKCJA STATYSTYCZNA (SUMARYCZNA) ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard(Icons.qr_code_2, 'Unikalne SKU', products.length.toString(), Colors.blueGrey),
                        _buildStatCard(Icons.bar_chart, 'Całkowity Stan', '$totalStock szt.', primaryColor),
                        _buildStatCard(Icons.attach_money, 'Wartość Brutto', '${totalValue.toStringAsFixed(2)} zł', Colors.green.shade700),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // --- Przyciski Eksportu ---
                    Wrap( 
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildActionButton(
                          icon: Icons.picture_as_pdf,
                          label: 'Eksport PDF',
                          onPressed: () => _generatePdf(products),
                          color: primaryColor,
                        ),
                        _buildActionButton(
                          icon: Icons.table_chart,
                          label: 'Eksport CSV',
                          onPressed: () => _generateCsv(products),
                          color: Colors.teal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // --- 2. LISTA SZCZEGÓŁOWA ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data = products[index].data() as Map<String, dynamic>;
                    final stock = data['stock'] ?? '0';
                    final price = data['price'] ?? '0.00';
                    final productCode = data['productCode'] ?? 'Brak kodu';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(Icons.inventory_2_outlined, color: primaryColor),
                        title: Text('$productCode - ${data['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Kategoria: ${data['category']} | Lokalizacja: ${data['location']}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$stock szt.', 
                              style: TextStyle(fontWeight: FontWeight.w900, color: primaryColor)),
                            Text(
                              '$price zł', 
                              style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // WIDŻET POMOCNICZY: Karta ze statystyką
  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}