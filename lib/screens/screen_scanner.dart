// Plik: lib/screens/screen_scanner.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeskanuj kod produktu'),
        // Dodajemy jawny przycisk cofania
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Wracamy z wartością null, jeśli użytkownik anuluje
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: Stack( // Używamy Stack, by nałożyć celownik na kamerę
        children: [
          MobileScanner(
            // Włączenie latarki w MobileScannerController
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              autoStart: true,
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? scannedCode = barcodes.first.rawValue;
                if (scannedCode != null) {
                  // Po wykryciu kodu natychmiast wracamy z wynikiem
                  Navigator.pop(context, scannedCode);
                }
              }
            },
          ),
          // Prosty celownik, by pokazać użytkownikowi, gdzie ma celować
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Umieść kod w czerwonej ramce',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}