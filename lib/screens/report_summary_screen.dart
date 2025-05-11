import 'package:flutter/material.dart';

class ReportSummaryScreen extends StatelessWidget {
  const ReportSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raport historii')),
      body: const Center(child: Text('Tu pojawi się historia')),
    );
  }
}
