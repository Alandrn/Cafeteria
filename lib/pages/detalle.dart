import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'producto_individual.dart';

class DetalleCategoriaPage extends StatelessWidget {
  final String nombreCategoria;
  final List<Map<String, dynamic>> productos;

  const DetalleCategoriaPage({
    super.key,
    required this.nombreCategoria,
    required this.productos,
  });

  @override
  Widget build(BuildContext context) {
    final Color azulUTPN = const Color(0xFF1565C0);
    final Color fondoGris = const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: Text(
            nombreCategoria.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: productos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 70, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Text("No hay productos disponibles",
                style:
                TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: productos.length,
        itemBuilder: (context, index) {
          final producto = productos[index];

          final String nombre =
              producto['nombre'] ?? "Producto sin nombre";
          final double precio =
          (producto['precio'] ?? 0).toDouble();
          final String urlImagen = producto['imagenUrl'] ?? "";

          // ✅ Lee 'detalle' primero (campo que guarda el admin),
          // si no existe intenta 'descripcion' (legacy),
          // si tampoco existe usa el texto por defecto
          final String detalleFinal = producto['detalle'] ??
              producto['descripcion'] ??
              "Delicioso producto de nuestra cafetería.";

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
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
                      // ✅ Ahora pasa 'detalle:' que es lo que
                      // espera el constructor de ProductoIndividualPage
                      detalle: detalleFinal,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // --- IMAGEN ---
                    Hero(
                      tag: 'img_prod_${nombre}_$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: urlImagen.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: urlImagen,
                          width: 85,
                          height: 85,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(
                                color: Colors.grey[100],
                                child: const Center(
                                    child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                          errorWidget:
                              (context, url, error) =>
                              Container(
                                color: Colors.grey[100],
                                child: const Icon(Icons.fastfood,
                                    color: Colors.grey),
                              ),
                        )
                            : Container(
                          width: 85,
                          height: 85,
                          color: Colors.grey[100],
                          child: const Icon(Icons.restaurant,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // --- INFO ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3133),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detalleFinal,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "\$${precio.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: azulUTPN,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- BOTÓN ---
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: azulUTPN.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add_rounded,
                          color: azulUTPN, size: 28),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}