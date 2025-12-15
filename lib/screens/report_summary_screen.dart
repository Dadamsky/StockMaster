import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportSummaryScreen extends StatefulWidget {
  const ReportSummaryScreen({super.key});

  @override
  State<ReportSummaryScreen> createState() => _ReportSummaryScreenState();
}

class _ReportSummaryScreenState extends State<ReportSummaryScreen> {
  bool _isLoading = true;
  Map<String, double> _monthlyIncome = {};
  Map<String, double> _monthlySales = {};

  @override
  void initState() {
    super.initState();
    _fetchAndProcessHistory();
  }

  /// Pobiera dane z Firestore i przetwarza je na sumy miesięczne.
  Future<void> _fetchAndProcessHistory() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('history').get();

    final Map<String, double> incomeData = {};
    final Map<String, double> salesData = {};

    final RegExp numRegex = RegExp(r'\d+'); // Regex do znalezienia ilości z opisu

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final code = data['code'] as String?;
      final date = data['date'] as Timestamp?;
      final description = data['description'] as String?;

      if (date == null || code == null || description == null) {
        continue;
      }

      // Wyciskanie ilości z opisu
      final match = numRegex.firstMatch(description);
      double quantity = 0.0;

      if (match != null) {
        quantity = double.tryParse(match.group(0) ?? '0') ?? 0.0;
      }

      if (quantity == 0.0) {
        continue;
      }

      final monthKey = DateFormat('yyyy-MM').format(date.toDate());

      if (code.startsWith('PM')) { // Przyjęcia Magazynowe
        incomeData[monthKey] = (incomeData[monthKey] ?? 0) + quantity;
      } else if (code.startsWith('SP')) { // Sprzedaż
        salesData[monthKey] = (salesData[monthKey] ?? 0) + quantity;
      }
    }

    setState(() {
      _monthlyIncome = incomeData;
      _monthlySales = salesData;
      _isLoading = false;
    });
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

  /// Helper do budowania wykresu słupkowego na podstawie mapy danych.
  Widget _buildBarChart(Map<String, double> data, Color color, String title) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Brak danych dla tej kategorii.'),
      );
    }

    final sortedKeys = data.keys.toList()..sort();
    final maxY = data.values.isEmpty
        ? 0.0
        : data.values.reduce((a, b) => a > b ? a : b) * 1.2;

    final barGroups = List.generate(sortedKeys.length, (index) {
      final value = data[sortedKeys[index]]!;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          height: 300,
          padding: const EdgeInsets.only(top: 16, right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: barGroups,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (BarChartGroupData group) => Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final monthKey = sortedKeys[group.x.toInt()];
                    return BarTooltipItem(
                      '$monthKey\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: rod.toY.toStringAsFixed(0),
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedKeys.length) {
                        final parts = sortedKeys[index].split('-');
                        if (parts.length == 2) {
                          final titleLabel = '${parts[1]}\n${parts[0].substring(2)}';
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(titleLabel, style: const TextStyle(fontSize: 10)),
                          );
                        }
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    // Obliczanie sum
    final totalIncome = _monthlyIncome.values.fold(0.0, (sum, val) => sum + val);
    final totalSales = _monthlySales.values.fold(0.0, (sum, val) => sum + val);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Podsumowanie Operacji', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchAndProcessHistory();
            },
            tooltip: 'Odśwież dane',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monthlyIncome.isEmpty && _monthlySales.isEmpty
              ? const Center(
                  child: Text(
                    'Brak danych historycznych do wyświetlenia wykresów.',
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- KARTY PODSUMOWANIA ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(Icons.arrow_downward, 'Całkowite przyjęcia (PM)', totalIncome.toStringAsFixed(0), Colors.green.shade700),
                          const SizedBox(width: 10),
                          _buildStatCard(Icons.arrow_upward, 'Całkowita sprzedaż (SP)', totalSales.toStringAsFixed(0), Colors.red.shade700),
                        ],
                      ),
                      const SizedBox(height: 30),
                      
                      // --- WYKRES PRZYJĘCIA ---
                      _buildBarChart(_monthlyIncome, Colors.blue, 'Przychody Magazynowe (PM)'),
                      
                      const SizedBox(height: 30),
                      
                      // --- WYKRES SPRZEDAŻY ---
                      _buildBarChart(_monthlySales, Colors.red, 'Rozchody/Sprzedaż (SP)'),
                    ],
                  ),
                ),
    );
  }
}