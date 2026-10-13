import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'producto_individual.dart';

class CategoriaPage extends StatelessWidget {
  const CategoriaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color azulUTPN = const Color(0xFF1565C0);
    final Color azulFondo = const Color(0xFFF5F7FA);

    final Object? args = ModalRoute.of(context)!.settings.arguments;
    final String categoria = args is String ? args : "Menú";

    return Scaffold(
      backgroundColor: azulFondo,
      appBar: AppBar(
        title: Text(
            categoria.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, size: 26),
            onPressed: () => Navigator.pushNamed(context, '/carrito'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('productos')
            .where('categoria', isEqualTo: categoria)
            .where('disponibilidad', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text("Error de conexión",
                    style: TextStyle(color: Colors.red[700])));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: azulUTPN));
          }

          final productos = snapshot.data!.docs;

          if (productos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  Text('No hay productos disponibles',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final doc = productos[index];
              final data = doc.data() as Map<String, dynamic>;

              String urlImagen = data['imagenUrl'] ?? "";
              String nombre = data['nombre'] ?? "Producto";
              double precio = (data['precio'] ?? 0).toDouble();

              // ✅ Lee 'detalle' primero, 'descripcion' como fallback
              String detalle = data['detalle'] ??
                  data['descripcion'] ??
                  "Sin descripción disponible.";

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10)
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductoIndividualPage(
                          nombre: nombre,
                          precio: precio,
                          imagenUrl: urlImagen,
                          // ✅ CORRECCIÓN: era 'descripcion:', ahora es 'detalle:'
                          detalle: detalle,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'img_${doc.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CachedNetworkImage(
                              imageUrl: urlImagen,
                              width: 85,
                              height: 85,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[100]),
                              errorWidget: (context, url, error) =>
                              const Icon(Icons.fastfood, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                detalle,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text('\$${precio.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: azulUTPN,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: Colors.grey[300]),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}