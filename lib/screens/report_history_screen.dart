import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

enum SortBy { date, code }

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<Map<String, dynamic>> historyReports = [];
  SortBy sortBy = SortBy.date;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    Query query = FirebaseFirestore.instance.collection('history');

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia operacji'),
        actions: [
          PopupMenuButton<SortBy>(
            onSelected: (SortBy selected) {
              setState(() {
                sortBy = selected;
              });
              fetchHistory();
            },
            icon: const Icon(Icons.sort),
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
      body: historyReports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: historyReports.length,
              itemBuilder: (context, index) {
                final report = historyReports[index];
                final date = (report['date'] as Timestamp).toDate();
                final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

                return ListTile(
                  title: Text(report['description'] ?? 'Brak opisu'),
                  subtitle: Text(formattedDate),
                  trailing: Text(report['code'] ?? 'Brak kodu'),
                );
              },
            ),
    );
  }
}
