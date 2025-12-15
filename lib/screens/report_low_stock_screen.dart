import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart'; 

class ReportLowStock extends StatefulWidget {
  const ReportLowStock({super.key});

  @override
  State<ReportLowStock> createState() => _ReportLowStockState();
}

class _ReportLowStockState extends State<ReportLowStock> {
  final CollectionReference _products =
      FirebaseFirestore.instance.collection('products');
  static const int niskiStanProg = 5; // Próg niskiego stanu

  // Funkcja generująca PDF
  Future<void> _generatePdf(List<QueryDocumentSnapshot> products) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Raport Niskich Stanów Magazynowych (< $niskiStanProg szt.)',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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

  // Funkcja generująca CSV
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

    await Printing.sharePdf(bytes: bytes, filename: 'raport_niski_stan.csv');
  }

  // Funkcja do ręcznego wysyłania alertu e-mail
  Future<void> _wyslijAlertEmail(List<QueryDocumentSnapshot> produkty) async {
    if (produkty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak produktów o niskim stanie.')),
      );
      return;
    }

    final emailBody = StringBuffer()
      ..writeln('Poniższe produkty mają niski stan magazynowy (poniżej $niskiStanProg szt.):\n');

    for (var doc in produkty) {
      final data = doc.data() as Map<String, dynamic>;
      emailBody.writeln(
          '- ${data['name']} (Kod: ${data['productCode']}) - Stan: ${data['stock']} szt.');
    }

    const email = 'damiankrito@gmail.com'; 
    const subject = 'ALERT: Niski stan magazynowy!';
    
    final uri = Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(emailBody.toString())}');

    try {
      if (await launchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Nie można uruchomić $uri';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas próby otwarcia klienta poczty: $e')),
      );
    }
  }
  
  // Funkcja pomocnicza do budowania przycisków w sekcji eksportu
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        elevation: 3,
      ),
    );
  }

  // Budowanie interfejsu użytkownika
  @override
  Widget build(BuildContext context) {
    // ✨ POPRAWKA: Inicjalizujemy kolory W METODZIE BUILD
    final Color alertColor = Colors.red.shade700;
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raport Niskich Stanów', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: alertColor, // Czerwony akcent dla ważnego raportu
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _products.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final produktyZNiskimStanem = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final stock = int.tryParse(data['stock'] ?? '0') ?? 0;
            return stock < niskiStanProg;
          }).toList();

          return Column(
            children: [
              // --- 1. PRZYCISKI EKSPORTU I ALARMOWANIA ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.1),
                  border: Border(bottom: BorderSide(color: alertColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Przycisk PDF
                    _buildActionButton(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      onPressed: () => _generatePdf(produktyZNiskimStanem),
                      color: primaryColor,
                    ),
                    // Przycisk CSV
                    _buildActionButton(
                      icon: Icons.table_chart,
                      label: 'CSV',
                      onPressed: () => _generateCsv(produktyZNiskimStanem),
                      color: primaryColor,
                    ),
                    // Przycisk E-MAIL
                    _buildActionButton(
                      icon: Icons.email_outlined,
                      label: 'Wyślij Alert',
                      onPressed: () => _wyslijAlertEmail(produktyZNiskimStanem),
                      color: alertColor,
                    ),
                  ],
                ),
              ),
              
              // --- 2. LISTA OSTRZEGAWCZA ---
              Expanded(
                child: produktyZNiskimStanem.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.thumb_up_alt_outlined, size: 50, color: Colors.green.shade600),
                            const SizedBox(height: 10),
                            const Text(
                              'Wszystko w porządku!\nBrak produktów poniżej progu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: produktyZNiskimStanem.length,
                        itemBuilder: (context, index) {
                          final doc = produktyZNiskimStanem[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final stock = data['stock'] ?? '0';
                          final code = data['productCode'] ?? 'Brak kodu';
                          final name = data['name'] ?? 'Brak nazwy';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: alertColor, width: 1.5), // Czerwona ramka
                            ),
                            child: ListTile(
                              leading: Icon(Icons.error_outline, color: alertColor, size: 30),
                              title: Text('$code - $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Lokalizacja: ${data['location']}\nKategoria: ${data['category']}',
                              ),
                              trailing: Text(
                                '$stock szt.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: alertColor,
                                ),
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
}