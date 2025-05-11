import 'package:flutter/material.dart';

class ReportLowStock extends StatelessWidget {
  const ReportLowStock({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raport historii')),
      body: const Center(child: Text('Tu pojawi się historia')),
    );
  }
}
