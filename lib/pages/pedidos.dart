import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PedidosPage extends StatelessWidget {
  const PedidosPage({super.key});

  final Color azulUTPN = const Color(0xFF1565C0);

  Future<void> _intentarCancelar(BuildContext context, String docId, String estatus) async {
    if (estatus != 'Pendiente') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se puede cancelar: El pedido ya está en preparación"))
      );
      return;
    }

    bool? confirmar = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("¿Cancelar Pedido?"),
        content: const Text("La orden se marcará como cancelada en el sistema de la cafetería."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("VOLVER")),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("SÍ, CANCELAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance.collection('ordenes').doc(docId).update({
          'estatus': 'Cancelado',
          'estado': 'Cancelado',
          'fechaCancelacion': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Pedido cancelado correctamente"), backgroundColor: Colors.orange)
          );
        }
      } catch (e) {
        debugPrint("Error al cancelar: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("ESTADO DE MIS PEDIDOS",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1.2)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("Inicia sesión para ver tus pedidos"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordenes')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // ✅ CORRECCIÓN: manejo de error en stream. Antes quedaba un spinner
          // infinito si Firestore devolvía un error de permisos u otro problema.
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 60),
                  const SizedBox(height: 16),
                  Text(
                    "No se pudieron cargar tus pedidos",
                    style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Verifica tu conexión e intenta de nuevo",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: azulUTPN));
          }

          final docs = snapshot.data!.docs;

          // Ordenar por fecha (más reciente arriba)
          docs.sort((a, b) {
            Timestamp f1 = a['fecha'] ?? Timestamp.now();
            Timestamp f2 = b['fecha'] ?? Timestamp.now();
            return f2.compareTo(f1);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.no_food_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  Text("No tienes pedidos activos", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String estatus = data['estatus'] ?? 'Pendiente';

              bool esListo = estatus == 'Listo' || estatus == 'Orden Lista';
              bool esCancelado = estatus == 'Cancelado';

              final List productos = data['productos'] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: esListo
                        ? Colors.green[50]
                        : (esCancelado ? Colors.red[50] : azulUTPN.withOpacity(0.05)),
                    child: Icon(
                      esListo ? Icons.check_circle : (esCancelado ? Icons.cancel : Icons.timer_outlined),
                      color: esListo ? Colors.green : (esCancelado ? Colors.red : azulUTPN),
                    ),
                  ),
                  title: Text("Folio: ${data['folio'] ?? '---'}",
                      style: TextStyle(fontWeight: FontWeight.bold, decoration: esCancelado ? TextDecoration.lineThrough : null)),
                  subtitle: Text("Estado: $estatus",
                      style: TextStyle(
                          color: esListo ? Colors.green : (esCancelado ? Colors.red : Colors.orange[800]),
                          fontWeight: FontWeight.bold,
                          fontSize: 13
                      )),
                  children: [
                    const Divider(),
                    ...productos.map((p) => ListTile(
                      dense: true,
                      title: Text("${p['cantidad']}x ${p['nombre']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: (p['notas'] != null && p['notas'].toString().isNotEmpty)
                          ? Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: azulUTPN.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                        child: Text("Nota: ${p['notas']}", style: TextStyle(color: azulUTPN, fontSize: 11, fontStyle: FontStyle.italic)),
                      )
                          : null,
                      trailing: Text("\$${(p['precio'] * (p['cantidad'] ?? 1)).toStringAsFixed(2)}"),
                    )).toList(),

                    if (esListo)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "¡PASA POR TU PEDIDO!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    if (estatus == 'Pendiente')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _intentarCancelar(context, doc.id, estatus),
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                            label: const Text("CANCELAR PEDIDO", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total pagado:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("\$${data['total'].toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: azulUTPN)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}