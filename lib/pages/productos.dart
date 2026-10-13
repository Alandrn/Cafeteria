import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'producto_individual.dart';
import '../models/carrito.dart';
import 'carrito.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final Color azulUTPN = const Color(0xFF1565C0);
  Map<String, Map<String, dynamic>> carrito = {};

  double get totalCart =>
      carrito.values.fold(0, (sum, item) => sum + (item['precio'] * item['cantidad']));
  int get cantidadItems =>
      carrito.values.fold(0, (sum, item) => sum + (item['cantidad'] as int));

  void _agregarAlCarrito(String id, String nombre, double precio) {
    setState(() {
      if (carrito.containsKey(id)) {
        carrito[id]!['cantidad']++;
      } else {
        carrito[id] = {'nombre': nombre, 'precio': precio, 'cantidad': 1, 'notas': ''};
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$nombre añadido al carrito"),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: azulUTPN,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('disponibilidad', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data!.docs;
        final categorias =
        docs.map((doc) => doc['categoria'] as String).toSet().toList();

        return DefaultTabController(
          length: categorias.length,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: azulUTPN,
              elevation: 0,
              centerTitle: true,
              title: const Text('MENÚ DISPONIBLE',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.2)),
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 4,
                tabs: categorias
                    .map((cat) => Tab(text: cat.toUpperCase()))
                    .toList(),
              ),
            ),
            body: TabBarView(
              children: categorias.map((catNombre) {
                final productosCat =
                docs.where((d) => d['categoria'] == catNombre).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: productosCat.length,
                  itemBuilder: (context, index) =>
                      _cardProducto(productosCat[index]),
                );
              }).toList(),
            ),
            floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
            floatingActionButton: carrito.isNotEmpty
                ? FloatingActionButton.extended(
              backgroundColor: Colors.green[700],
              onPressed: () => _mostrarResumenPedido(),
              icon: const Icon(Icons.shopping_cart_checkout,
                  color: Colors.white),
              label: Text(
                  "REVISAR PEDIDO (\$${totalCart.toStringAsFixed(2)})",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _cardProducto(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String id = doc.id;
    final bool enCarrito = carrito.containsKey(id);

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductoIndividualPage(
              nombre: data['nombre'],
              precio: (data['precio'] as num).toDouble(),
              imagenUrl: data['imagenUrl'] ?? "",
              // ✅ CORRECCIÓN: lee 'detalle' primero, 'descripcion' como fallback
              detalle: data['detalle'] ??
                  data['descripcion'] ??
                  "Delicioso producto de la cafetería UTPN.",
            ),
          ),
        );

        setState(() {
          for (var p in Carrito.productos) {
            carrito[p['nombre']] = {
              'nombre': p['nombre'],
              'precio': p['precio'],
              'cantidad': p['cantidad'],
              'notas': p['notas'] ?? ''
            };
          }
        });
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                    child: CachedNetworkImage(
                      imageUrl: data['imagenUrl'] ?? "",
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  ),
                  if (enCarrito)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: azulUTPN,
                        child: Text("${carrito[id]!['cantidad']}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['nombre'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1),
                  const SizedBox(height: 2),
                  Text("\$${data['precio']}",
                      style: TextStyle(
                          color: azulUTPN,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: azulUTPN,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _agregarAlCarrito(
                          id,
                          data['nombre'],
                          (data['precio'] as num).toDouble()),
                      child: const Text("AÑADIR",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _mostrarResumenPedido() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("TU ORDEN",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ...carrito.entries.map((e) => ListTile(
                  title: Text(e.value['nombre'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: (e.value['notas'] != null &&
                      e.value['notas'] != "")
                      ? Text("Nota: ${e.value['notas']}",
                      style: TextStyle(
                          color: azulUTPN, fontSize: 12))
                      : null,
                  leading: CircleAvatar(
                      backgroundColor: azulUTPN,
                      child: Text("${e.value['cantidad']}",
                          style: const TextStyle(
                              color: Colors.white))),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle,
                        color: Colors.red),
                    onPressed: () {
                      setState(() {
                        if (carrito[e.key]!['cantidad'] > 1) {
                          carrito[e.key]!['cantidad']--;
                        } else {
                          carrito.remove(e.key);
                        }
                      });
                      setModalState(() {});
                      if (carrito.isEmpty) Navigator.pop(context);
                    },
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("\$${totalCart.toStringAsFixed(2)}",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: azulUTPN)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700]),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarCompraFinal();
                    },
                    child: const Text("CONFIRMAR PEDIDO",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmarCompraFinal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() as Map<String, dynamic>?;

      num deuda = data?['Deuda'] ?? 0;
      bool bloqueado = data?['bloqueado'] ?? false;

      if (deuda > 0 || bloqueado) {
        _mostrarAlertaBloqueo(deuda);
        return;
      }

      final nombreUsuario = data?['nombre'] ?? "Cliente";
      String folio =
          "UTPN-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";

      await FirebaseFirestore.instance.collection('ordenes').add({
        'userId': user.uid,
        'nombreUsuario': nombreUsuario,
        'productos': carrito.values.toList(),
        'total': totalCart,
        'estatus': 'Pendiente',
        'fecha': FieldValue.serverTimestamp(),
        'folio': folio.toUpperCase(),
      });

      setState(() {
        carrito.clear();
        Carrito.limpiar();
      });
      _showSuccess(folio);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _mostrarAlertaBloqueo(num deuda) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.report_problem_rounded, color: azulUTPN),
            const SizedBox(width: 10),
            const Text("CUENTA RESTRINGIDA",
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "No puedes realizar pedidos por adeudo o restricción de cuenta."),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10)),
              child: Text("Adeudo: \$${deuda.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ),
            const SizedBox(height: 15),
            const Text(
                "Por favor, acude a la cafetería para solucionar tu situación.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ENTENDIDO",
                style: TextStyle(
                    color: azulUTPN, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String folio) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("¡Pedido Enviado!"),
        content: Text(
            "Tu folio es: $folio\n\nPodrás ver el estatus en la sección 'Mis Pedidos'."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("OK"))
        ],
      ),
    );
  }
}