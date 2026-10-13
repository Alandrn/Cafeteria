import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/carrito.dart'; // Asegúrate de que esta ruta sea la correcta

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  bool _isSending = false;
  final Color azulUTPN = const Color(0xFF1565C0);

  // --- FUNCIÓN DE CONFIRMACIÓN CORREGIDA ---
  void _confirmarOrden() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() as Map<String, dynamic>?;

      // LEEMOS DEUDA Y BLOQUEO MANUAL
      num montoDeuda = data?['Deuda'] ?? 0;
      bool estaBloqueado = data?['bloqueado'] ?? false;

      if (montoDeuda > 0 || estaBloqueado == true) {
        _mostrarAlertaBloqueo(montoDeuda);
        setState(() => _isSending = false);
        return;
      }

      String nombreParaAdmin = data?['nombre'] ?? data?['nombreUsuario'] ?? "Alumno UTPN";

      // Enviamos a Firebase
      await Carrito.enviarPedidoAFirebase(nombreParaAdmin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Pedido enviado con éxito!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Carrito.limpiar(); // Limpiamos el carrito
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al procesar: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _mostrarAlertaBloqueo(num deuda) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.report_problem_rounded, color: azulUTPN),
            const SizedBox(width: 10),
            const Text("CUENTA RESTRINGIDA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("No puedes realizar pedidos por adeudo o restricción de cuenta."),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
              child: Text("Adeudo: \$${deuda.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            const SizedBox(height: 15),
            const Text("Por favor, acude a la cafetería para solucionar tu situación.",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ENTENDIDO", style: TextStyle(color: azulUTPN, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Confirmar mi Pedido", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Carrito.productos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_shopping_cart_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 15),
            const Text("No hay productos seleccionados", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: Carrito.productos.length,
              itemBuilder: (context, index) {
                final p = Carrito.productos[index];
                String? textoNota = p['notas'];
                bool tieneNotas = textoNota != null && textoNota.trim().isNotEmpty;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(p['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("Cantidad: ${p['cantidad']} pz", style: TextStyle(color: Colors.grey[600])),
                        if (tieneNotas) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                            child: Text("Nota: $textoNota", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    trailing: Text("\$${(p['precio'] * p['cantidad']).toStringAsFixed(2)}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: azulUTPN, fontSize: 17)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL ESTIMADO", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text("\$${Carrito.obtenerTotal().toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 26, color: azulUTPN, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _isSending
                      ? CircularProgressIndicator(color: azulUTPN)
                      : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _confirmarOrden,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: azulUTPN,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0
                      ),
                      child: const Text("CONFIRMAR Y ENVIAR",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}