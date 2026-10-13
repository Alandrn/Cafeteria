import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Carrito {
  static List<Map<String, dynamic>> productos = [];

  static void agregarProducto(String nombre, double precio, String notas) {
    // Buscamos si ya existe el mismo producto con la MISMA nota
    int index = productos.indexWhere((p) =>
    p['nombre'] == nombre && p['notas'] == notas);

    if (index != -1) {
      productos[index]['cantidad']++;
    } else {
      productos.add({
        "nombre": nombre,
        "precio": precio,
        "cantidad": 1,
        "notas": notas
      });
    }
  }

  static double obtenerTotal() =>
      productos.fold(0, (sum, item) => sum + (item['precio'] * item['cantidad']));

  static void limpiar() => productos.clear();

  static Future<void> enviarPedidoAFirebase(String nombreAlumno) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || productos.isEmpty) return;

    // ✅ CORRECCIÓN: usamos los últimos 6 dígitos del timestamp para mayor
    // unicidad y consistencia. Antes se usaba substring(7) aquí y substring(9)
    // en productos.dart, lo que generaba folios de longitud diferente.
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String folio = 'UTPN-${timestamp.substring(timestamp.length - 6)}';

    await FirebaseFirestore.instance.collection('ordenes').add({
      'userId': user.uid,
      'nombreUsuario': nombreAlumno,
      'folio': folio,
      'productos': List.from(productos),
      'total': obtenerTotal(),
      'estatus': 'Pendiente',
      'estado': 'Pendiente',
      'fecha': FieldValue.serverTimestamp(),
    });

    // Nota: La limpieza se maneja en la página tras confirmar el éxito
  }
}