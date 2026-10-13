import 'package:flutter/material.dart';
import '../models/carrito.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductoIndividualPage extends StatefulWidget {
  final String nombre;
  final double precio;
  final String imagenUrl;
  // ✅ Parámetro unificado como 'detalle' — coincide con el campo en Firestore
  final String detalle;

  const ProductoIndividualPage({
    super.key,
    required this.nombre,
    required this.precio,
    required this.imagenUrl,
    required this.detalle,
  });

  @override
  State<ProductoIndividualPage> createState() => _ProductoIndividualPageState();
}

class _ProductoIndividualPageState extends State<ProductoIndividualPage> {
  final TextEditingController _notasController = TextEditingController();
  final Color azulUTPN = const Color(0xFF1565C0);

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "DETALLE DEL PRODUCTO",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CABECERA DE IMAGEN ---
            Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(50)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(50)),
                    child: Hero(
                      tag: 'img_prod_${widget.nombre}',
                      child: widget.imagenUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: widget.imagenUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Icon(
                            Icons.fastfood,
                            size: 80,
                            color: azulUTPN.withOpacity(0.2)),
                      )
                          : Icon(Icons.fastfood,
                          size: 80, color: azulUTPN.withOpacity(0.2)),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NOMBRE Y PRECIO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.nombre,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF212121)),
                        ),
                      ),
                      Text(
                        "\$${widget.precio.toStringAsFixed(2)}",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: azulUTPN),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // --- DESCRIPCIÓN ---
                  const Text("DESCRIPCIÓN",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  // ✅ Ahora usa widget.detalle correctamente
                  Text(
                    widget.detalle.isNotEmpty
                        ? widget.detalle
                        : "Producto fresco preparado al momento en la cafetería UTPN.",
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.4),
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 20),

                  // --- NOTAS PARA LA COCINA ---
                  Row(
                    children: [
                      Icon(Icons.comment_bank_outlined,
                          size: 20, color: azulUTPN),
                      const SizedBox(width: 8),
                      Text(
                        "¿INSTRUCCIONES ESPECIALES?",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: azulUTPN),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notasController,
                    maxLines: 2,
                    maxLength: 80,
                    decoration: InputDecoration(
                      hintText: "Ej. Sin cebolla, extra picante, etc.",
                      hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF5F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      counterText: "",
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),

      // --- BOTÓN DE ACCIÓN ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: () {
            Carrito.agregarProducto(
                widget.nombre,
                widget.precio,
                _notasController.text.trim());

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("¡${widget.nombre} añadido!"),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: azulUTPN,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            elevation: 4,
          ),
          child: const Text("AGREGAR AL PEDIDO",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      ),
    );
  }
}