import 'package:flutter/material.dart';
import 'report_stock_screen.dart';
import 'report_history_screen.dart';
import 'report_low_stock_screen.dart';
import 'report_summary_screen.dart';
// Upewniamy się, że mamy import ReportLowStock

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  // Funkcja pomocnicza do budowania nowoczesnej karty raportu
  Widget _buildReportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
    Color accentColor = Colors.blueGrey, // Kolor akcentu
  }) {
    return Card(
      elevation: 4, // Lepszy cień
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell( // Używamy InkWell, by dodać efekt dotyku
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 32, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle, 
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty Analityczne', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Raport stanów magazynowych
          _buildReportTile(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Raport Stanów Magazynowych',
            subtitle: 'Aktualny stan produktów z opcją eksportu',
            destination: const ReportStockScreen(),
            accentColor: Colors.blue.shade700,
          ),
          const SizedBox(height: 16),
          
          // 2. Raport operacji (historia)
          _buildReportTile(
            context,
            icon: Icons.history_toggle_off,
            title: 'Raport Operacji (Historia)',
            subtitle: 'Filtruj przyjęcia, przesunięcia i sprzedaże',
            destination: const ReportHistoryScreen(),
            accentColor: Colors.teal.shade600,
          ),
          const SizedBox(height: 16),
          
          // 3. Raport niskich stanów
          _buildReportTile(
            context,
            icon: Icons.warning_amber_rounded,
            title: 'Raport Niskich Stanów',
            subtitle: 'Lista produktów z małym zapasem',
            destination: const ReportLowStock(), // Zmieniono z ReportLowStockScreen na ReportLowStock
            accentColor: Colors.red.shade700,
          ),
          const SizedBox(height: 16),
          
          // 4. Podsumowanie sprzedaży i przyjęć
          _buildReportTile(
            context,
            icon: Icons.bar_chart_outlined,
            title: 'Podsumowanie Sprzedaży (Wykresy)',
            subtitle: 'Statystyki z wykresami i eksportem PDF',
            destination: const ReportSummaryScreen(),
            accentColor: Colors.orange.shade700,
          ),
        ],
      ),
    );
  }
}