import 'package:flutter/material.dart';

class ReportHistoryScreen extends StatelessWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raport historii')),
      body: const Center(child: Text('Tu pojawi się historia')),
    );
  }
}
