import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

import '../services/firebase_service.dart';
import 'location_picker_dialog.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  final String name;
  final String category;
  final String stock;
  final String location;
  final String productCode;
  final String price; 
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
    required this.price, 
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
      builder: (context) =>
          LocationPickerDialog(initialLocation: _selectedLocation),
    );

    if (newLocation != null) {
      setState(() {
        _selectedLocation = newLocation;
      });
      widget.onLocationUpdated(widget.productId, newLocation);
    }
  }

  void _generateLabelPdf() async {
    final pdf = pw.Document();
    final barcode = Barcode.code128();
    final codeToGenerate = widget.productCode.isNotEmpty ? widget.productCode : 'BRAK KODU';
    final barcodeImage = barcode.toSvg(codeToGenerate, width: 200, height: 80);

    pdf.addPage(
      pw.Page(
        pageFormat:
            const PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(widget.name, style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 10),
                pw.Text(widget.productCode,
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.SvgImage(svg: barcodeImage, width: 200, height: 80),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18), 
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), 
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productCode, style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Potwierdź usunięcie'),
                  content: Text('Czy na pewno chcesz usunąć ${widget.name} (${widget.productCode})?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
                    TextButton(
                      onPressed: () {
                        widget.onProductDeleted(widget.productId);
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('Usuń', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Nagłówek Produktu ---
            Text(widget.name, style: Theme.of(context).textTheme.headlineSmall),
            Text('Kategoria: ${widget.category}', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
            const SizedBox(height: 25),

            // --- SEKCJA GŁÓWNYCH STATYSTYK (4 KOMPAKTOWE KARTY) ---
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.8,
              children: [
                // STAN MAGAZYNOWY
                _buildInfoCard(
                  title: 'Stan Magazynowy',
                  value: '${widget.stock} szt.',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.blue.shade800,
                ),
                // CENA
                _buildInfoCard(
                  title: 'Cena Sprzedaży',
                  value: '${widget.price} zł',
                  icon: Icons.attach_money,
                  color: Colors.green.shade700,
                ),
                // KOD PRODUKTU
                _buildInfoCard(
                  title: 'Kod Produktu',
                  value: widget.productCode,
                  icon: Icons.qr_code_2,
                  color: Colors.black54,
                ),
                // LOKALIZACJA
                _buildInfoCard(
                  title: 'Obecna Lokalizacja',
                  value: _selectedLocation,
                  icon: Icons.place_outlined,
                  color: Colors.orange.shade800,
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            // --- SEKCJA OPERACJI I FORMULARZY (EDYTUJ) ---
            Text('Edycja i Operacje', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 15),

            // FORMULARZE EDYCJI
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nazwa produktu',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) {
                widget.onProductUpdated(
                    widget.productId, value, _stockController.text);
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _stockController,
              decoration: InputDecoration(
                labelText: 'Ilość',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                widget.onProductUpdated(
                    widget.productId, _nameController.text, value);
              },
            ),
            const SizedBox(height: 25),

            // PRZYCISKI OPERACYJNE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Przycisk generowania etykiety (PDF)
                ElevatedButton.icon(
                  onPressed: _generateLabelPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generuj etykietę'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                
                // Przycisk przesunięcia lokalizacji (Change Location)
                ElevatedButton.icon(
                  onPressed: _changeLocation,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Zmień lokalizację'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(),

            // --- SEKCJA HISTORII ---
            const Text('Historia Operacji:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            SizedBox(
              height: 300, 
              child: StreamBuilder(
                stream: _firebaseService.getProductHistory(widget.productId),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('Brak historii dla tego produktu'));
                  }

                  final history = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final data = entry.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(data['description'] ?? 'Brak opisu', style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            'Kod: ${data['code']} | Data: ${DateFormat('dd.MM.yyyy HH:mm').format(date)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          leading: Icon(
                            data['type'] == 'PM' ? Icons.arrow_downward : (data['type'] == 'MM' ? Icons.sync_alt : Icons.arrow_upward),
                            color: data['type'] == 'PM' ? Colors.green : (data['type'] == 'MM' ? Colors.blueGrey : Colors.red),
                          ),
                        ),
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