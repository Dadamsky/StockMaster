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

  Future<void> _generatePdf(List<QueryDocumentSnapshot> products) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Raport stanów magazynowych', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Kod', 'Nazwa', 'Kategoria', 'Lokalizacja', 'Stan'],
                data: products.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return [
                    data['productCode'] ?? '',
                    data['name'] ?? '',
                    data['category'] ?? '',
                    data['location'] ?? '',
                    data['stock'] ?? ''
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

  Future<void> _generateCsv(List<QueryDocumentSnapshot> products) async {
    final List<List<String>> rows = [
      ['Kod', 'Nazwa', 'Kategoria', 'Lokalizacja', 'Stan']
    ];

    for (var doc in products) {
      final data = doc.data() as Map<String, dynamic>;
      rows.add([
        data['productCode'] ?? '',
        data['name'] ?? '',
        data['category'] ?? '',
        data['location'] ?? '',
        data['stock'] ?? ''
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await Printing.sharePdf(bytes: bytes, filename: 'raport_stanow.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raport stanów magazynowych')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _products.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final products = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Eksport PDF'),
                      onPressed: () => _generatePdf(products),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Eksport CSV'),
                      onPressed: () => _generateCsv(products),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data = products[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.inventory),
                      title: Text('${data['productCode']} - ${data['name']}'),
                      subtitle: Text(
                        'Kategoria: ${data['category']}, Lokalizacja: ${data['location']}, Stan: ${data['stock']} szt.',
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
}
