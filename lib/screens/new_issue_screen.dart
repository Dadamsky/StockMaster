import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stockmaster/models/cart_items.dart';
import 'package:stockmaster/services/firebase_service.dart';
import 'screen_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class NewIssueScreen extends StatefulWidget {
  const NewIssueScreen({super.key});

  @override
  State<NewIssueScreen> createState() => _NewIssueScreenState();
}

class _NewIssueScreenState extends State<NewIssueScreen> {
  final List<IssueCartItem> _cartItems = [];
  final FirebaseService _firebaseService = FirebaseService();
  bool _isProcessing = false;

  // Kontrolery dla dialogu faktury
  final _invoiceNameController = TextEditingController();
  final _invoiceNipController = TextEditingController();
  final _invoiceAddressController = TextEditingController();

  /// --- 1. FUNKCJA SKANOWANIA I DODAWANIA DO KOSZYKA ---
  Future<void> _scanAndAddProduct() async {
    final String? scannedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedBarcode == null || scannedBarcode.isEmpty || !mounted) {
      return;
    }

    // Małe opóźnienie dla stabilności nawigacji
    await Future.delayed(const Duration(milliseconds: 100));

    final productDoc =
        await _firebaseService.getProductByBarcode(scannedBarcode);

    if (productDoc == null) {
      _showErrorSnackbar('Nie znaleziono produktu o kodzie: $scannedBarcode');
      return;
    }

    // Sprawdź cenę
    final data = productDoc.data() as Map<String, dynamic>;
    final price = double.tryParse(data['price'] ?? '0.0') ?? 0.0;
    if (price <= 0.0) {
      _showErrorSnackbar(
          'BŁĄD: Produkt "${data['name']}" nie ma zdefiniowanej ceny w bazie!');
      return;
    }

    if (!mounted) return;
    final int? quantity = await _showQuantityDialog(data);

    if (quantity == null || quantity <= 0) {
      return;
    }

    setState(() {
      final index =
          _cartItems.indexWhere((item) => item.productId == productDoc.id);

      if (index != -1) {
        _cartItems[index].quantityToIssue += quantity;
      } else {
        _cartItems.add(IssueCartItem.fromDoc(productDoc, quantity));
      }
    });
  }

  /// --- 2. DIALOG DO WPISYWANIA ILOŚCI ---
  Future<int?> _showQuantityDialog(Map<String, dynamic> productData) {
    final TextEditingController qtyController = TextEditingController();
    final int stockOnHand = int.tryParse(productData['stock'] ?? '0') ?? 0;
    String? errorText;

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(productData['name'] ?? 'Brak nazwy'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kod: ${productData['productCode']}'),
                  Text('Obecny stan: $stockOnHand szt.'),
                  Text('Cena: ${productData['price'] ?? '0.00'} zł',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Ilość do wydania',
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyController.text);
                    if (qty == null || qty <= 0) {
                      setDialogState(() {
                        errorText = 'Wprowadź poprawną ilość';
                      });
                    } else if (qty > stockOnHand) {
                      setDialogState(() {
                        errorText = 'Za mało na stanie ($stockOnHand szt.)';
                      });
                    } else {
                      Navigator.pop(dialogContext, qty);
                    }
                  },
                  child: const Text('Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// --- 3. GŁÓWNA FUNKCJA ZATWIERDZENIA ---
  Future<void> _processIssue() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    // Krok 1: Walidacja stanów magazynowych
    for (var item in _cartItems) {
      final doc =
          await _firebaseService.productsCollection.doc(item.productId).get();
      final data = doc.data() as Map<String, dynamic>;
      final currentStock = int.tryParse(data['stock'] ?? '0') ?? 0;

      if (item.quantityToIssue > currentStock) {
        _showErrorSnackbar(
            'BŁĄD WALIDACJI: Niewystarczający stan dla ${item.name}!');
        setState(() {
          _isProcessing = false;
        });
        return;
      }
    }

    // Krok 2: Pokaż dialog wyboru dokumentu
    if (mounted) {
      _showDocumentTypeDialog();
    }
  }

  /// --- 4. DIALOG WYBORU DOKUMENTU ---
  void _showDocumentTypeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wybierz typ dokumentu'),
          content: const Text(
              'Wydanie zostanie zatwierdzone po wygenerowaniu dokumentu.'),
          actions: [
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () {
                setState(() {
                  _isProcessing = false;
                });
                Navigator.pop(context);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.receipt),
              label: const Text('Paragon'),
              onPressed: () {
                Navigator.pop(context);
                _generateAndShowReceipt();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.description),
              label: const Text('Faktura'),
              onPressed: () {
                Navigator.pop(context);
                _showInvoiceDetailsDialog();
              },
            ),
          ],
        );
      },
    );
  }

  /// --- 5. DIALOG DO WPROWADZENIA DANYCH FAKTURY ---
  void _showInvoiceDetailsDialog() {
    _invoiceNameController.clear();
    _invoiceNipController.clear();
    _invoiceAddressController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dane Nabywcy do Faktury'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _invoiceNameController,
                  decoration: const InputDecoration(labelText: 'Nazwa firmy'),
                ),
                TextField(
                  controller: _invoiceNipController,
                  decoration: const InputDecoration(
                      labelText: 'NIP (np. 123-456-78-90)'),
                ),
                TextField(
                  controller: _invoiceAddressController,
                  decoration: const InputDecoration(
                      labelText: 'Adres (Ulica, Kod, Miasto)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () {
                setState(() {
                  _isProcessing = false;
                });
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('Generuj Fakturę'),
              onPressed: () {
                if (_invoiceNameController.text.isEmpty ||
                    _invoiceNipController.text.isEmpty ||
                    _invoiceAddressController.text.isEmpty) {
                  _showErrorSnackbar('Wypełnij wszystkie pola faktury');
                  return;
                }
                final buyerDetails = {
                  'name': _invoiceNameController.text,
                  'nip': _invoiceNipController.text,
                  'address': _invoiceAddressController.text,
                };
                Navigator.pop(context);
                _generateAndShowInvoice(buyerDetails);
              },
            ),
          ],
        );
      },
    );
  }

  /// --- 6A. GENERUJ PARAGON ---
  Future<void> _generateAndShowReceipt() async {
    final pdf = await _buildPdf(_cartItems);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
    await _saveTransactionToDatabase();
  }

  /// --- 6B. GENERUJ FAKTURĘ ---
  Future<void> _generateAndShowInvoice(
      Map<String, String> buyerDetails) async {
    final pdf = await _buildPdf(_cartItems, buyerDetails: buyerDetails);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
    await _saveTransactionToDatabase();
  }

  /// --- 7. ZAPIS TRANSAKCJI DO BAZY ---
  Future<void> _saveTransactionToDatabase() async {
    final historyCode = await _firebaseService.generateHistoryCode("SP");
    final descriptionBuffer =
        StringBuffer('Wydano ${_cartItems.length} poz.:\n');
    double totalValue = 0.0;

    for (var item in _cartItems) {
      final newStock = item.stockOnHand - item.quantityToIssue;
      await _firebaseService.updateStock(item.productId, newStock);
      descriptionBuffer.writeln(
          '- ${item.name} (${item.quantityToIssue} szt. po ${item.price.toStringAsFixed(2)} zł)');
      totalValue += item.totalValue;
    }

    await _firebaseService.historyCollection.add({
      'code': historyCode,
      'type': 'SP',
      'date': Timestamp.now(),
      'description': descriptionBuffer.toString(),
      'totalValue': totalValue,
      'items': _cartItems
          .map((item) => {
                'productId': item.productId,
                'name': item.name,
                'quantity': item.quantityToIssue,
                'price': item.price,
              })
          .toList(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wydanie $historyCode zatwierdzone!'),
          backgroundColor: Colors.green,
        ),
      );
      _invoiceNameController.clear();
      _invoiceNipController.clear();
      _invoiceAddressController.clear();
      Navigator.pop(context);
    }
  }

  /// --- 8. BUDOWANIE PDF ---
  Future<pw.Document> _buildPdf(List<IssueCartItem> cartItems,
      {Map<String, String>? buyerDetails}) async {
    final pdf = pw.Document();
    double totalNet = 0;
    const double vatRate = 0.23;

    for (var item in cartItems) {
      totalNet += item.totalValue / (1 + vatRate);
    }
    double totalVat = totalNet * vatRate;
    double totalGross = totalNet + totalVat;

    final isInvoice = buyerDetails != null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isInvoice ? 'Faktura VAT' : 'Paragon',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Sprzedawca:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('StockMaster Sp. z o. o.'),
                      pw.Text('ul. Magazynowa 1, 00-001 Warszawa'),
                      pw.Text('NIP: 525-000-00-00'),
                    ],
                  ),
                  if (isInvoice)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Nabywca:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(buyerDetails['name'] ?? ''),
                        pw.Text(buyerDetails['address'] ?? ''),
                        pw.Text('NIP: ${buyerDetails['nip'] ?? ''}'),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                  'Data: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Container(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 1))),
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('Nazwa',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text('Ilość',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('Cena (Netto)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('Wartość (Netto)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              ...cartItems.map((item) {
                final itemNetPrice = item.price / (1 + vatRate);
                final itemNetValue = itemNetPrice * item.quantityToIssue;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey))),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 3, child: pw.Text(item.name)),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(item.quantityToIssue.toString(),
                            textAlign: pw.TextAlign.right)),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('${itemNetPrice.toStringAsFixed(2)} zł',
                            textAlign: pw.TextAlign.right)),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('${itemNetValue.toStringAsFixed(2)} zł',
                            textAlign: pw.TextAlign.right)),
                  ]));
              }),
              pw.SizedBox(height: 30),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Suma Netto: ${totalNet.toStringAsFixed(2)} zł',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('VAT (23%): ${totalVat.toStringAsFixed(2)} zł',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Divider(),
                          pw.Text(
                              'Suma Brutto: ${totalGross.toStringAsFixed(2)} zł',
                              style: pw.TextStyle(
                                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ])
                  ]),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double cartTotalValue =
        _cartItems.fold(0.0, (sum, item) => sum + item.totalValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowe Wydanie (SP)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _isProcessing ? null : _scanAndAddProduct,
            tooltip: 'Skanuj, aby dodać',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(
                    child: Text(
                      'Koszyk jest pusty.\nUżyj ikony skanera, aby dodać produkty.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return ListTile(
                        title: Text('${item.productCode} - ${item.name}'),
                        subtitle: Text(
                            'Ilość: ${item.quantityToIssue} x ${item.price.toStringAsFixed(2)} zł  (Na stanie: ${item.stockOnHand})'),
                        trailing: Text(
                          '${item.totalValue.toStringAsFixed(2)} zł',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Suma Brutto: ${cartTotalValue.toStringAsFixed(2)} zł',
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(_isProcessing
                          ? 'PRZETWARZANIE...'
                          : 'Zatwierdź wydanie (${_cartItems.length} poz.)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _isProcessing ? null : _processIssue,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}