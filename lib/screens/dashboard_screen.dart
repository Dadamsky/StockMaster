import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockmaster/screens/reports_screen.dart';
import 'user_management_screen.dart';
import 'product_list_screen.dart';
import 'login_screen.dart';
import 'deliveries_screen.dart';


class DashboardScreen extends StatelessWidget {
  final String login;
  const DashboardScreen({super.key, required this.login});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockMaster - Pulpit nawigacyjny'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Zalogowany: $login',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj się',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3,
                children: [
                  _buildCard(context, '📦 Produkty', () {
                    _navigateTo(context, const ProductListScreen());
                  }),
                  _buildCard(context, '🚚 Dostawy', () {
                    _navigateTo(context, const DeliveriesScreen());
                  }),
                  _buildCard(context, '📊 Raporty', () {
                     _navigateTo(context, const ReportsScreen());
                  }),
                  _buildCard(context, '⚙️ Użytkownicy', () {
                    _navigateTo(context, const UserManagementScreen());
                  }),
                  _buildCard(context, '🧷 W trakcie pracy', () { // Może system rezerwacji produktu pod zamówienie
                    _navigateTo;
                  }),
                  _buildCard(context, '🧷 W trakcie pracy', () { // Może system zamówień i wysyłek
                    _navigateTo;
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
