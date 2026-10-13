import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoCard extends StatelessWidget {
  // Recibimos el documento completo de la orden desde Firestore
  final QueryDocumentSnapshot orden;

  const PedidoCard({super.key, required this.orden});

  // Lógica de los 10 minutos para permitir la cancelación
  bool _puedeCancelar(Timestamp? fecha) {
    if (fecha == null) return false;
    DateTime horaPedido = fecha.toDate();
    DateTime ahora = DateTime.now();
    int diferencia = ahora.difference(horaPedido).inMinutes;
    return diferencia < 10;
  }

  @override
  Widget build(BuildContext context) {
    // Extraemos los datos exactos de tu colección 'ordenes'
    String estatus = orden['estatus'] ?? 'En proceso';
    String folio = orden['folio'] ?? '000';
    Timestamp? fecha = orden['fecha_creacion'] as Timestamp?;

    // Configuramos colores: Naranja para espera, Verde para "Ya puedes recogerlo"
    bool esListo = estatus == "Orden Lista";
    Color colorEstatus = esListo ? Colors.green : Colors.orange;

    return Card(
      elevation: esListo ? 8 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
            color: esListo ? Colors.green : Colors.transparent,
            width: 2
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorEstatus,
          child: Icon(
            esListo ? Icons.notifications_active : Icons.restaurant,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
            "Folio: $folio",
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        subtitle: Text(
            "Estado: $estatus",
            style: TextStyle(color: colorEstatus, fontWeight: FontWeight.bold)
        ),
        // Si el alumno aún tiene tiempo y el pedido no se ha entregado, mostramos botón
        trailing: (estatus == 'En proceso' && _puedeCancelar(fecha))
            ? ElevatedButton(
          onPressed: () => _confirmarCancelacion(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text("CANCELAR", style: TextStyle(color: Colors.white, fontSize: 10)),
        )
            : (esListo ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.keyboard_arrow_down)),

        // Al tocar la tarjeta, se despliega la lista de lo que pidió
        children: [
          const Divider(),
          ... (orden['productos'] as List).map((p) => ListTile(
            dense: true,
            title: Text("${p['cantidad']}x ${p['nombre']}"),
            trailing: Text("\$${p['precio']}"),
          )),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _confirmarCancelacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cancelar pedido?"),
        content: const Text("Tienes 10 minutos para arrepentirte. ¿Deseas eliminar este pedido de la cocina?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('ordenes').doc(orden.id).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pedido eliminado."), backgroundColor: Colors.red),
              );
            },
            child: const Text("SÍ, CANCELAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}