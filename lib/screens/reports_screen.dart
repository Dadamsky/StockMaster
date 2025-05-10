import 'package:flutter/material.dart';
import 'report_stock_screen.dart';
import 'report_history_screen.dart';
import 'report_low_stock_screen.dart';
import 'report_summary_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportTile(
            context,
            icon: Icons.inventory,
            title: 'Raport stanów magazynowych',
            subtitle: 'Aktualny stan produktów z opcją eksportu',
            destination: const ReportStockScreen(),
          ),
          const SizedBox(height: 12),
          _buildReportTile(
            context,
            icon: Icons.history,
            title: 'Raport operacji (historia)',
            subtitle: 'Filtruj przyjęcia, przesunięcia i sprzedaże',
            destination: const ReportHistoryScreen(),
          ),
          const SizedBox(height: 12),
          _buildReportTile(
            context,
            icon: Icons.warning_amber_rounded,
            title: 'Raport niskich stanów',
            subtitle: 'Lista produktów z małym zapasem',
            destination: const ReportLowStockScreen(),
          ),
          const SizedBox(height: 12),
          _buildReportTile(
            context,
            icon: Icons.bar_chart,
            title: 'Podsumowanie sprzedaży i przyjęć',
            subtitle: 'Statystyki z wykresami i eksportem PDF',
            destination: const ReportSummaryScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
      ),
    );
  }
}
