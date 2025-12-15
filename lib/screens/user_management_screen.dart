// Import dla Authentication
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'magazynier';

  final List<String> _roles = ['admin', 'magazynier', 'odczyt'];

  // --- LOGIKA BIZNESOWA ---

  Future<void> _createUser() async {
    final login = _loginController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (login.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola')),
      );
      return;
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      String? uid = userCredential.user?.uid;

      if (uid != null) {
        await _db.collection('users').doc(uid).set({
          'login': login,
          'email': email,
          'role': _selectedRole,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pomyślnie dodano użytkownika do Auth i Firestore!'),
            backgroundColor: Colors.green,
          ),
        );

        _loginController.clear();
        _emailController.clear();
        _passwordController.clear();
        setState(() {
          _selectedRole = 'magazynier';
        });
      }
    } on FirebaseAuthException catch (e) {
      // errory obsługa
      String message;
      if (e.code == 'weak-password') {
        message = 'Podane hasło jest zbyt słabe.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Konto dla tego adresu e-mail już istnieje.';
      } else if (e.code == 'invalid-email') {
        message = 'Adres e-mail jest nieprawidłowy.';
      } else {
        message = 'Błąd uwierzytelniania: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      // errory obsługa
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wystąpił błąd: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Usuwanie i pop-up z ostrzeżeniem
  void _deleteUserFromFirestore(String docId, String email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Potwierdź usunięcie"),
          content: Text(
              "Czy na pewno chcesz usunąć użytkownika z Firestore: $email? \n\nUWAGA: Konto Authentication (login i hasło) będzie nadal istniało!"),
          actions: [
            TextButton(
              child: const Text("Anuluj"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Usuń", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await _db.collection('users').doc(docId).delete();

                if (mounted) Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Usunięto profil z Firestore. Wymagane ręczne usunięcie z Firebase Auth.'),
                      backgroundColor: Colors.orange),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Funkcja pomocnicza do tworzenia wypełnionych pól tekstowych
  InputDecoration _getInputDecoration(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarządzanie Użytkownikami', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- SEKCJA DODAWANIA UŻYTKOWNIKA ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Dodaj nowego pracownika',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: _loginController,
                      decoration: _getInputDecoration('Login', icon: Icons.badge),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _emailController,
                      decoration: _getInputDecoration('Email (do logowania)', icon: Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _getInputDecoration('Hasło', icon: Icons.lock_outline),
                    ),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: _getInputDecoration('Rola', icon: Icons.security_outlined),
                      items: _roles.map((role) {
                        return DropdownMenuItem(value: role, child: Text(role));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 25),
                    
                    ElevatedButton.icon(
                      onPressed: _createUser,
                      icon: const Icon(Icons.person_add),
                      label: const Text('DODAJ UŻYTKOWNIKA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- SEKCJA LISTY UŻYTKOWNIKÓW ---
            const SizedBox(height: 40),
            const Text('Lista użytkowników',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    final login = data['login'] ?? 'UID: ${user.id}';
                    final role = data['role'];
                    final email = data['email'] ?? 'Brak emaila'; 
                    final validRole = _roles.contains(role) ? role : 'odczyt';
                    final roleColor = validRole == 'admin' ? Colors.red.shade700 : (validRole == 'magazynier' ? Colors.orange.shade700 : Colors.blueGrey);


                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(Icons.person_pin, color: roleColor),
                        title: Text(login, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(email),
                        trailing: SizedBox(
                          width: 150,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Dropdown do zmiany roli
                              Flexible(
                                child: DropdownButton<String>(
                                  value: validRole,
                                  style: TextStyle(color: roleColor, fontWeight: FontWeight.w600),
                                  items: _roles.map((r) {
                                    return DropdownMenuItem(value: r, child: Text(r));
                                  }).toList(),
                                  onChanged: (newRole) {
                                    if (newRole != null) {
                                      _db
                                          .collection('users')
                                          .doc(user.id)
                                          .update({'role': newRole});
                                    }
                                  },
                                ),
                              ),
                              // Przycisk usuwania
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  _deleteUserFromFirestore(user.id, email); 
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}