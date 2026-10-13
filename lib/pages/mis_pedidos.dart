import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MisPedidosPage extends StatelessWidget {
  const MisPedidosPage({super.key});

  final Color azulUTPN = const Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("MIS PEDIDOS",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.1)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("Inicia sesión para consultar tus pedidos"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordenes')
            .where('userId', isEqualTo: user.uid)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar historial"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: azulUTPN));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  const Text("Aún no tienes pedidos registrados",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => TarjetaPedido(orden: docs[index]),
          );
        },
      ),
    );
  }
}

class TarjetaPedido extends StatelessWidget {
  final QueryDocumentSnapshot orden;
  const TarjetaPedido({super.key, required this.orden});

  // Solo se puede cancelar si sigue en "Pendiente"
  bool _puedeCancelar(String estatus) {
    String e = estatus.toLowerCase();
    return e == 'pendiente';
  }

  @override
  Widget build(BuildContext context) {
    final data = orden.data() as Map<String, dynamic>;
    final String estatus = (data['estatus'] ?? data['estado'] ?? 'Pendiente').toString();
    final Timestamp? fecha = data['fecha'] as Timestamp?;
    final List productos = data['productos'] ?? [];
    final double total = (data['total'] ?? 0).toDouble();
    final Color azulUTPN = const Color(0xFF1565C0);
    final String folio = data['folio'] ?? '---';

    String fechaFormateada = fecha != null
        ? DateFormat('dd/MM/yyyy - hh:mm a').format(fecha.toDate())
        : 'Fecha no disponible';

    Color colorStatus;
    IconData icono;

    // Lógica de colores para el Alumno
    switch (estatus) {
      case 'Listo':
        colorStatus = Colors.green;
        icono = Icons.check_circle;
        break;
      case 'En proceso':
        colorStatus = Colors.orange;
        icono = Icons.restaurant;
        break;
      case 'Entregado':
        colorStatus = Colors.grey;
        icono = Icons.done_all;
        break;
      case 'Cancelado':
      case 'No recogido':
        colorStatus = Colors.red;
        icono = Icons.error;
        break;
      default:
        colorStatus = azulUTPN;
        icono = Icons.timer;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.withOpacity(0.2))
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorStatus.withOpacity(0.1),
          child: Icon(icono, color: colorStatus, size: 22),
        ),
        title: Text("Folio: $folio",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(fechaFormateada, style: const TextStyle(fontSize: 12)),
        trailing: Text("\$${total.toStringAsFixed(2)}",
            style: TextStyle(fontWeight: FontWeight.bold, color: azulUTPN, fontSize: 16)),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (estatus != 'Entregado' && estatus != 'Cancelado' && estatus != 'No recogido')
                  Center(
                    child: Column(
                      children: [
                        QrImageView(
                          data: folio,
                          version: QrVersions.auto,
                          size: 150.0,
                          foregroundColor: azulUTPN,
                        ),
                        const Text("Muestra este QR en ventanilla", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("RESUMEN:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    Text(estatus.toUpperCase(), style: TextStyle(color: colorStatus, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                ...productos.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${item['nombre']} (x${item['cantidad']})", style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text("\$${((item['precio'] ?? 0) * (item['cantidad'] ?? 1)).toStringAsFixed(2)}"),
                          ],
                        ),
                        if ((item['notas'] != null && item['notas'] != "") || (item['nota'] != null && item['nota'] != ""))
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.yellow[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3))
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_note, size: 16, color: Colors.brown),
                                const SizedBox(width: 5),
                                Expanded(child: Text("Nota: ${item['notas'] ?? item['nota']}", style: const TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),

                // BOTÓN DE CANCELACIÓN CORREGIDO
                if (_puedeCancelar(estatus)) ...[
                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _confirmarCancelacion(context, orden.id),
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      label: const Text("CANCELAR PEDIDO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- FUNCIÓN DE CANCELACIÓN BLINDADA ---
  void _confirmarCancelacion(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("¿Cancelar pedido?"),
        content: const Text("Esta acción notificará a la cafetería y el pedido se moverá al historial de cancelados."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("VOLVER")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // CORRECCIÓN CRÍTICA: Actualizamos ambos campos para que el Admin los detecte
                // y NO usamos delete() para que no desaparezca.
                await FirebaseFirestore.instance.collection('ordenes').doc(docId).update({
                  'estatus': 'Cancelado',
                  'estado': 'Cancelado',
                  'fechaModificacion': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(c);
              },
              child: const Text("SÍ, CANCELAR", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}