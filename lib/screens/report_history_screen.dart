import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

// Używamy enum do sortowania i filtrowania
enum SortBy { date, code }
enum FilterType { all, pm, sp, mm } // Typy transakcji: Wszystkie, Przyjęcie, Sprzedaż, Przesunięcie

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<Map<String, dynamic>> historyReports = [];
  SortBy sortBy = SortBy.date;
  FilterType filterType = FilterType.all; // Domyślnie pokazujemy wszystko
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  // Uproszczona nazwa dla koloru akcentu
  Color get primaryColor => Theme.of(context).primaryColor;


  /// Pobiera dane z Firestore i aplikuje sortowanie/filtrowanie
  Future<void> fetchHistory() async {
    setState(() {
      _isLoading = true;
    });

    Query query = FirebaseFirestore.instance.collection('history');

    // --- LOGIKA FILTROWANIA ---
    if (filterType != FilterType.all) {
      final typeString = filterType.toString().split('.').last.toUpperCase(); // np. 'PM'
      query = query.where('type', isEqualTo: typeString);
    }

    // --- LOGIKA SORTOWANIA ---
    if (sortBy == SortBy.date) {
      query = query.orderBy('date', descending: true);
    } else if (sortBy == SortBy.code) {
      query = query.orderBy('code');
    }

    final snapshot = await query.get();

    setState(() {
      historyReports = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      _isLoading = false;
    });
  }

  /// Zwraca ikonę i kolor na podstawie typu transakcji (PM, SP, MM)
  Map<String, dynamic> _getStyleForType(String type) {
    switch (type) {
      case 'PM': // Przyjęcie Magazynowe
        return {'icon': Icons.arrow_downward, 'color': Colors.green.shade600};
      case 'SP': // Sprzedaż / Wydanie
        return {'icon': Icons.arrow_upward, 'color': Colors.red.shade600};
      case 'MM': // Przesunięcie Magazynowe
        return {'icon': Icons.sync_alt, 'color': Colors.blue.shade600};
      default:
        return {'icon': Icons.help_outline, 'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Operacji', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // --- 1. FILTROWANIE PO TYPIE (PM/SP/MM) ---
          PopupMenuButton<FilterType>(
            onSelected: (FilterType selected) {
              setState(() {
                filterType = selected;
              });
              fetchHistory();
            },
            icon: Icon(Icons.filter_list, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: FilterType.all,
                child: Text('Wszystkie typy'),
              ),
              const PopupMenuItem(
                value: FilterType.pm,
                child: Text('Przyjęcia (PM)'),
              ),
              const PopupMenuItem(
                value: FilterType.sp,
                child: Text('Sprzedaż (SP)'),
              ),
              const PopupMenuItem(
                value: FilterType.mm,
                child: Text('Przesunięcia (MM)'),
              ),
            ],
          ),
          
          // --- 2. SORTOWANIE PO DATY/KODZIE ---
          PopupMenuButton<SortBy>(
            onSelected: (SortBy selected) {
              setState(() {
                sortBy = selected;
              });
              fetchHistory();
            },
            icon: const Icon(Icons.sort, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortBy.date,
                child: Text('Sortuj po dacie'),
              ),
              const PopupMenuItem(
                value: SortBy.code,
                child: Text('Sortuj po kodzie'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyReports.isEmpty
              ? Center(
                  child: Text(
                      'Brak danych. Spróbuj zmienić filtr (obecny: ${filterType.toString().split('.').last.toUpperCase()})'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: historyReports.length,
                  itemBuilder: (context, index) {
                    final report = historyReports[index];
                    final date = (report['date'] as Timestamp).toDate();
                    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);
                    final type = report['type'] ?? 'Brak';
                    final style = _getStyleForType(type);

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: style['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(style['icon'], color: style['color']),
                        ),
                        title: Text(report['description'] ?? 'Brak opisu', style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(formattedDate),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              report['code'] ?? 'Brak kodu', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: style['color'])
                            ),
                            Text(type, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}