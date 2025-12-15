import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import 'report_low_stock_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';
import 'product_list_screen.dart';
import 'login_screen.dart';
import 'deliveries_screen.dart';
import 'mobile_operations_screen.dart' as mob_ops;

class DashboardScreen extends StatefulWidget {
  final String login;
  const DashboardScreen({super.key, required this.login});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  final Map<String, List<String>> _rolePermissions = {
    'admin': ['📦 Produkty', '🚚 Dostawy', '📊 Raporty', '⚙️ Użytkownicy', '📱 Mobilne Operacje'],
    'magazynier': ['📦 Produkty', '🚚 Dostawy', '📱 Mobilne Operacje'],
    'odczyt': ['📊 Raporty', '📦 Produkty'],
  };


  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  bool _canView(String role, String title) {
    if (role == 'admin') return true;
    final allowedTitles = _rolePermissions[role] ?? [];
    return allowedTitles.contains(title);
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                title.substring(2).trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUserId != null 
          ? _db.collection('users').doc(_currentUserId).snapshots() 
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final userRole = (snapshot.data?.data() as Map<String, dynamic>?)?['role'] ?? 'odczyt'; 
        
        // Definicja wszystkich możliwych przycisków
        final Map<String, IconData> menuItems = {
          '📦 Produkty': Icons.inventory_2_outlined,
          '🚚 Dostawy': Icons.local_shipping_outlined,
          '📊 Raporty': Icons.bar_chart_outlined,
          '⚙️ Użytkownicy': Icons.group_outlined,
          '📱 Mobilne Operacje': Icons.qr_code_scanner,
        };

        // Filtrowanie elementów na podstawie roli
        final filteredItems = menuItems.keys.where((title) => _canView(userRole, title)).map((title) {
          final icon = menuItems[title]!;
          final screenMap = {
            '📦 Produkty': const ProductListScreen(),
            '🚚 Dostawy': const DeliveriesScreen(),
            '📊 Raporty': const ReportsScreen(),
            '⚙️ Użytkownicy': const UserManagementScreen(),
            '📱 Mobilne Operacje': const mob_ops.MobileOperationsScreen(), 
          };

          return _buildCard(context, title, icon, () {
            if (screenMap[title] is! Container) {
              _navigateTo(context, screenMap[title]!);
            }
          });
        }).toList();


        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('StockMaster', style: TextStyle(fontWeight: FontWeight.w600)),
                floating: true,
                pinned: true,
                actions: [
                  // Ikona alertu
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('products').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink(); 
                      }
                      const int niskiStanProg = 5;
                      
                      final produktyZNiskimStanem = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final stock = int.tryParse(data['stock'] ?? '0') ?? 0;
                        return stock < niskiStanProg;
                      }).toList();

                      return _LowStockAlertIcon(
                        lowStockProducts: produktyZNiskimStanem,
                      );
                    },
                  ),
                  
                  // Status zalogowania
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: Text(
                        '${widget.login} ($userRole)', 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _logout, 
                    icon: const Icon(Icons.logout),
                    tooltip: 'Wyloguj się',
                  )
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0, 
                  children: filteredItems,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _LowStockAlertIcon extends StatefulWidget {
  final List<QueryDocumentSnapshot> lowStockProducts;

  const _LowStockAlertIcon({required this.lowStockProducts});

  @override
  _LowStockAlertIconState createState() => _LowStockAlertIconState();
}

class _LowStockAlertIconState extends State<_LowStockAlertIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lowStockProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    String tooltipMessage = 'Niski stan magazynowy:\n';
    for (var doc in widget.lowStockProducts) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data.containsKey('name') ? data['name'] : 'Brak nazwy';
      final stock = data.containsKey('stock') ? data['stock'] : '?';
      tooltipMessage += '- $name (Stan: $stock)\n';
    }

    return Tooltip(
      message: tooltipMessage.trim(), 
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportLowStock()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: FadeTransition(
            opacity: _controller, 
            child: const Icon(
              Icons.warning_amber_rounded, 
              color: Colors.redAccent,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}