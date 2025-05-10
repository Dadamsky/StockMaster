import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final CollectionReference productsCollection =
      FirebaseFirestore.instance.collection('products');

  final CollectionReference historyCollection =
      FirebaseFirestore.instance.collection('history'); // 🔹 Kolekcja historii

  // Generowanie kodu historii (PM-0001, MM-0001)
  Future<String> generateHistoryCode(String type) async {
    try {
      final snapshot = await historyCollection
          .where('type', isEqualTo: type)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return "$type-0001"; // Jeśli brak wpisów, zaczynamy od 0001
      } else {
        final Map<String, dynamic> lastDoc = snapshot.docs.first.data() as Map<String, dynamic>;
        final lastCode = lastDoc['code'] ?? '';

        // Sprawdzamy, czy format jest poprawny
        if (lastCode.startsWith(type) && lastCode.contains('-')) {
          final lastNumber = int.tryParse(lastCode.split('-')[1]) ?? 0;
          final newNumber = lastNumber + 1;
          return "$type-${newNumber.toString().padLeft(4, '0')}";
        } else {
          print("❌ Błąd: Nieprawidłowy format kodu w Firestore: $lastCode");
          return "$type-0001"; // Jeśli format błędny, resetujemy do 0001
        }
      }
    } catch (e) {
      print("❌ Błąd generowania kodu historii ($type): $e");
      return "$type-ERROR"; // Jeśli wystąpi błąd, zwracamy komunikat błędu
    }
  }



  // Dodanie nowego produktu + zapis historii
  Future<void> addProduct(String name, String category, String stock, String location) async {
    try {
      final productCode = await generateProductCode();
      final productDoc = await productsCollection.add({
        'name': name,
        'category': category,
        'stock': stock,
        'location': location,
        'productCode': productCode,
      });

      print("✅ Produkt dodany: ID = ${productDoc.id}, Kod = $productCode");

      final historyCode = await generateHistoryCode("PM");
      await historyCollection.add({
        'productId': productDoc.id,
        'code': historyCode,
        'type': "PM", // Przyjęcie magazynowe
        'date': Timestamp.now(),
        'description': "Produkt utworzony: $name w lokalizacji $location",
      });

      print("✅ Wpis PM ($historyCode) dodany do historii dla produktu ${productDoc.id}");
    } catch (e) {
      print("❌ Błąd podczas dodawania produktu: $e");
    }
  }

  // Aktualizacja lokalizacji + zapis historii
  Future<void> updateLocation(String productId, String newLocation) async {
    try {
      await productsCollection.doc(productId).update({
        'location': newLocation,
      });

      print("✅ Lokalizacja produktu $productId zaktualizowana do $newLocation");

      final historyCode = await generateHistoryCode("MM");
      await historyCollection.add({
        'productId': productId,
        'code': historyCode,
        'type': "MM", // Przesunięcie magazynowe
        'date': Timestamp.now(),
        'description': "Produkt przesunięty do: $newLocation",
      });

      print("✅ Wpis MM ($historyCode) dodany do historii dla produktu $productId");
    } catch (e) {
      print("❌ Błąd podczas aktualizacji lokalizacji: $e");
    }
  }

    // Pobranie historii produktu
  Stream<QuerySnapshot> getProductHistory(String productId) {
    return historyCollection
        .where('productId', isEqualTo: productId) // 🔹 Filtrowanie po productId
        .orderBy('date', descending: true) // 🔹 Sortowanie od najnowszych wpisów
        .snapshots();
  }

  
  // Generowanie kodu produktu
  Future<String> generateProductCode() async {
    try {
      final snapshot = await productsCollection.orderBy('productCode', descending: true).limit(1).get();

      if (snapshot.docs.isEmpty) {
        return "SM0001"; // Jeśli nie ma produktów, zaczynamy od SM0001
      } else {
        final lastCode = snapshot.docs.first['productCode'];
        final lastNumber = int.parse(lastCode.substring(2));
        final newNumber = lastNumber + 1;
        return "SM${newNumber.toString().padLeft(4, '0')}";
      }
    } catch (e) {
      print("❌ Błąd podczas generowania kodu produktu: $e");
      return "SM-ERROR";
    }
  }

  // Pobieranie produktów w czasie rzeczywistym
  Stream<QuerySnapshot> getProducts() {
    return productsCollection.snapshots();
  }

  // Aktualizacja nazwy i ilości
  Future<void> updateProduct(String productId, String name, String stock) async {
    try {
      await productsCollection.doc(productId).update({
        'name': name,
        'stock': stock,
      });

      print("✅ Produkt $productId zaktualizowany: Nazwa = $name, Ilość = $stock");
    } catch (e) {
      print("❌ Błąd podczas aktualizacji produktu: $e");
    }
  }

  // Usunięcie produktu
  Future<void> deleteProduct(String productId) async {
    try {
      await productsCollection.doc(productId).delete();
      print("✅ Produkt $productId usunięty");
    } catch (e) {
      print("❌ Błąd podczas usuwania produktu: $e");
    }
  }
  // AKtualizacja stanu produktów
  Future<void> updateStock(String productId, int newStock) async {
  await productsCollection.doc(productId).update({'stock': newStock.toString()});
  }
  
}
