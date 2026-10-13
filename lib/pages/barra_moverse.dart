import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importaciones de tus páginas
import 'productos.dart';
import 'pedidos.dart';
import 'perfil.dart';
import 'chat_usuario.dart'; // <--- IMPORTANTE: Asegúrate de tener este archivo creado

class BarraMoverse extends StatefulWidget {
  const BarraMoverse({super.key});

  @override
  State<BarraMoverse> createState() => _BarraMoverseState();
}

class _BarraMoverseState extends State<BarraMoverse> {
  int _indice = 0;
  final Color azulUTPN = const Color(0xFF1565C0);

  // RESTAURACIÓN: Lista completa de 4 páginas
  final List<Widget> _paginas = [
    const ProductosPage(),
    const PedidosPage(),
    const ChatUsuarioPage(), // <--- RESTAURADA
    const PerfilPage(),
  ];

  @override
  void initState() {
    super.initState();
    _configurarNotificaciones();
  }

  Future<void> _configurarNotificaciones() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        String? uid = FirebaseAuth.instance.currentUser?.uid;

        if (token != null && uid != null) {
          // Usamos merge para guardar el token sin tocar saldo o deudas
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': token,
            'ultimoAcceso': FieldValue.serverTimestamp(),
            'online': true,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("Error en Notificaciones: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack evita que las páginas se recarguen al cambiar de pestaña
      body: IndexedStack(
        index: _indice,
        children: _paginas,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _indice,
          onTap: (valor) => setState(() => _indice = valor),
          backgroundColor: Colors.white,
          selectedItemColor: azulUTPN,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu_rounded),
                label: 'MENÚ'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                activeIcon: Icon(Icons.shopping_bag),
                label: 'PEDIDOS'),
            BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                activeIcon: Icon(Icons.chat_bubble_rounded),
                label: 'SOPORTE'), // <--- BOTÓN RESTAURADO
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'PERFIL'),
          ],
        ),
      ),
    );
  }
}