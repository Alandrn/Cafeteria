import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/carrito.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  final Color azulUTPN = const Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar perfil"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          double deuda = (userData['Deuda'] ?? 0.0).toDouble();
          String rol = userData['rol'] ?? 'cliente';
          String nombre = userData['nombre'] ?? "Usuario UTPN";

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: azulUTPN,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    nombre.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [azulUTPN, const Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white,
                            backgroundImage: AssetImage('assets/avatar.png'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            rol == 'admin' ? "ADMINISTRATIVO" : "CLIENTE UTPN",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // --- ESTADO DE CUENTA ---
                      _buildCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          leading: CircleAvatar(
                            backgroundColor: deuda > 0 ? Colors.red[50] : Colors.green[50],
                            child: Icon(Icons.account_balance_wallet_rounded,
                                color: deuda > 0 ? Colors.red : Colors.green),
                          ),
                          title: const Text("Estado de Cuenta", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(deuda > 0 ? "Saldo pendiente de pago" : "Cuenta al corriente",
                              style: TextStyle(color: deuda > 0 ? Colors.red : Colors.green, fontSize: 12)),
                          trailing: Text("\$${deuda.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: deuda > 0 ? Colors.red : Colors.green)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- QR DINÁMICO ---
                      _buildCard(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('ordenes')
                              .where('userId', isEqualTo: user?.uid)
                              .where('estatus', whereIn: ['Pendiente', 'En proceso', 'Listo', 'Orden Lista'])
                              .limit(1)
                              .snapshots(),
                          builder: (context, orderSnap) {
                            bool hayPedido = orderSnap.hasData && orderSnap.data!.docs.isNotEmpty;
                            String qrData = user?.uid ?? "no-uid";
                            String infoQR = "MI CÓDIGO DE USUARIO";

                            if (hayPedido) {
                              qrData = orderSnap.data!.docs.first['folio'] ?? "S/F";
                              infoQR = "FOLIO ACTUAL: $qrData";
                            }

                            return Column(
                              children: [
                                const SizedBox(height: 10),
                                Text(infoQR,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: azulUTPN, fontSize: 12, letterSpacing: 1.1)),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: QrImageView(
                                      data: qrData,
                                      size: 160,
                                      foregroundColor: hayPedido ? Colors.green[700]! : Colors.black87
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  hayPedido
                                      ? "Presenta este código para recoger tu pedido"
                                      : "Escanea este código en caja para identificarte",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 10),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 25),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("   TUS PEDIDOS ACTIVOS",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 11, letterSpacing: 1.1)),
                      ),
                      const SizedBox(height: 10),

                      _buildListaPedidosActivos(user?.uid),

                      const SizedBox(height: 40),

                      // --- BOTÓN CERRAR SESIÓN ---
                      // ✅ CORRECCIÓN: se limpia el carrito antes de cerrar sesión
                      // para evitar que persista entre diferentes cuentas de usuario.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Carrito.limpiar();
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/login', (route) => false);
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text("CERRAR SESIÓN"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: child,
    );
  }

  Widget _buildListaPedidosActivos(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ordenes')
          .where('userId', isEqualTo: uid)
          .where('estatus', whereIn: ['Pendiente', 'En proceso', 'Listo', 'Orden Lista'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        var pedidos = snapshot.data!.docs;

        if (pedidos.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text("No hay pedidos en preparación.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }

        return Column(
          children: pedidos.map((doc) {
            String estatus = doc['estatus'];
            bool esListo = estatus == 'Listo' || estatus == 'Orden Lista';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: esListo ? Colors.green.withOpacity(0.3) : Colors.grey[200]!),
              ),
              child: ListTile(
                leading: Icon(
                    esListo ? Icons.check_circle_rounded : Icons.pending_rounded,
                    color: esListo ? Colors.green : Colors.orange),
                title: Text("Folio: ${doc['folio']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(estatus,
                    style: TextStyle(color: esListo ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                trailing: Text("\$${doc['total']}", style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}