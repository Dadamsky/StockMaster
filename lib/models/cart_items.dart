import 'package:cloud_firestore/cloud_firestore.dart';


class IssueCartItem {
  final String productId;
  final String name;
  final String productCode;
  final int stockOnHand;
  int quantityToIssue;
  final double price;

  IssueCartItem({
    required this.productId,
    required this.name,
    required this.productCode,
    required this.stockOnHand,
    required this.quantityToIssue,
    required this.price,
  });

  factory IssueCartItem.fromDoc(QueryDocumentSnapshot doc, int quantity) {
    final data = doc.data() as Map<String, dynamic>;
    return IssueCartItem(
      productId: doc.id,
      name: data['name'] ?? 'Brak nazwy',
      productCode: data['productCode'] ?? 'Brak kodu',
      stockOnHand: int.tryParse(data['stock'] ?? '0') ?? 0,
      price: double.tryParse(data['price'] ?? '0.0') ?? 0.0,
      quantityToIssue: quantity,
    );
  }

  double get totalValue => price * quantityToIssue;
}