// Plik: auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Logowanie użytkownika za pomocą loginu i hasła
  Future<User?> login(String login, String password) async {
    try {
      // Znajdź email przypisany do loginu
      final snapshot = await _db.collection('users').where('login', isEqualTo: login).limit(1).get();
      if (snapshot.docs.isEmpty) {
        print("Nie znaleziono użytkownika o loginie: $login");
        return null;
      }
      final email = snapshot.docs.first['email'];

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Logowanie nieudane: $e");
      return null;
    }
  }

  // Wylogowanie
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Pobranie roli użytkownika
  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc['role'] : null;
  }
} 
