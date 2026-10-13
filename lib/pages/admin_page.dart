import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ─── SELECTOR DE MODO ────────────────────────────────────────────────────────
// Pantalla que aparece al entrar al panel admin para elegir Cocina o Caja.
// Mismo usuario, misma app, diferente vista.
class AdminModeSelectorPage extends StatelessWidget {
  const AdminModeSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color azulUTPN = const Color(0xFF1565C0);
    final Color azulOscuro = const Color(0xFF0D47A1);

    return Scaffold(
      backgroundColor: azulOscuro,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant, size: 70, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                "CAFETERÍA UTPN",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                "Selecciona el modo de esta estación",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 60),

              // BOTÓN COCINA
              _ModeButton(
                icon: Icons.soup_kitchen_rounded,
                label: "MODO COCINA",
                description: "Ver y gestionar órdenes en preparación",
                color: Colors.orange[700]!,
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CocinaPage()),
                ),
              ),
              const SizedBox(height: 20),

              // BOTÓN CAJA
              _ModeButton(
                icon: Icons.point_of_sale_rounded,
                label: "MODO CAJA",
                description: "Panel completo de administración",
                color: azulUTPN,
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                ),
              ),

              const SizedBox(height: 60),
              TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
                label: const Text("Cerrar sesión",
                    style: TextStyle(color: Colors.white54)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 42),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PÁGINA DE COCINA (KDS) ───────────────────────────────────────────────────
// Vista diseñada para que el cocinero vea las órdenes en tiempo real.
// Prioridades de diseño:
//   - Texto grande y legible desde distancia
//   - Ordenes más antiguas arriba (orden de llegada)
//   - Alerta sonora + visual cuando llega una nueva orden
//   - Botones grandes para COCINAR y LISTO con mínima interacción
//   - Notas especiales muy destacadas en rojo/amarillo
class CocinaPage extends StatefulWidget {
  const CocinaPage({super.key});

  @override
  State<CocinaPage> createState() => _CocinaPageState();
}

class _CocinaPageState extends State<CocinaPage> with TickerProviderStateMixin {
  final Color naranja = const Color(0xFFE65100);
  final Color verde = const Color(0xFF2E7D32);
  final Color fondoOscuro = const Color(0xFF1A1A2E);
  final Color tarjetaOscura = const Color(0xFF16213E);

  // Guardamos los IDs de órdenes conocidas para detectar órdenes nuevas
  final Set<String> _ordenesConocidas = {};
  bool _primeraVez = true;

  // Animación de parpadeo para órdenes nuevas
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _flashAnimation =
        Tween<double>(begin: 1.0, end: 0.3).animate(_flashController);
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  // ✅ Detecta órdenes nuevas y emite alerta visual con SnackBar llamativo.
  // Para sonido real se necesita el paquete audioplayers o just_audio,
  // por ahora usamos vibración + SnackBar de pantalla completa.
  void _alertarNuevaOrden(String folio) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.fixed,
        content: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "🔔 NUEVA ORDEN: $folio",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cambiarEstatus(String id, String estatus) {
    FirebaseFirestore.instance
        .collection('ordenes')
        .doc(id)
        .update({'estatus': estatus, 'estado': estatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoOscuro,
      appBar: AppBar(
        backgroundColor: naranja,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.soup_kitchen_rounded, size: 26),
            SizedBox(width: 10),
            Text("COCINA",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1.5)),
          ],
        ),
        actions: [
          // Botón para volver al selector de modo
          TextButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminModeSelectorPage()),
            ),
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            label: const Text("CAMBIAR MODO",
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ordenes')
            .where('estatus', whereIn: ['Pendiente', 'En proceso'])
            .orderBy('fecha', descending: false) // Más antiguas arriba
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error de conexión",
                  style: TextStyle(color: Colors.red[300], fontSize: 18)),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: naranja),
            );
          }

          final ordenes = snapshot.data!.docs;

          // ── Detección de órdenes nuevas ──
          if (!_primeraVez) {
            for (var doc in ordenes) {
              if (!_ordenesConocidas.contains(doc.id)) {
                final data = doc.data() as Map<String, dynamic>;
                // Solo alertar si es Pendiente (recién llegada)
                if ((data['estatus'] ?? '') == 'Pendiente') {
                  _alertarNuevaOrden(data['folio'] ?? 'S/F');
                }
              }
            }
          }

          // Actualizamos el set de órdenes conocidas
          _ordenesConocidas.clear();
          for (var doc in ordenes) {
            _ordenesConocidas.add(doc.id);
          }
          _primeraVez = false;

          if (ordenes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 100, color: verde.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text(
                    "Sin órdenes pendientes",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ordenes.length,
            itemBuilder: (context, index) {
              final doc = ordenes[index];
              final data = doc.data() as Map<String, dynamic>;
              final String estatus =
              (data['estatus'] ?? 'Pendiente').toString();
              final bool esPendiente = estatus == 'Pendiente';
              final List productos = data['productos'] ?? [];
              final String folio = data['folio'] ?? 'S/F';
              final String nombre =
                  data['nombreUsuario'] ?? data['nombreAlumno'] ?? 'Alumno';

              // Tiempo desde que llegó la orden
              String tiempoEspera = "";
              if (data['fecha'] != null) {
                final DateTime fechaOrden =
                (data['fecha'] as Timestamp).toDate();
                final int minutos =
                    DateTime.now().difference(fechaOrden).inMinutes;
                tiempoEspera = minutos == 0
                    ? "Justo ahora"
                    : "Hace $minutos min";
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: tarjetaOscura,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    // Borde naranja para pendientes, azul para en proceso
                    color: esPendiente
                        ? naranja
                        : const Color(0xFF1565C0),
                    width: esPendiente ? 3 : 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── CABECERA DE LA ORDEN ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: esPendiente
                            ? naranja.withOpacity(0.2)
                            : const Color(0xFF1565C0).withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                      ),
                      child: Row(
                        children: [
                          // Indicador de estado animado para pendientes
                          if (esPendiente)
                            FadeTransition(
                              opacity: _flashAnimation,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                    color: naranja,
                                    shape: BoxShape.circle),
                              ),
                            )
                          else
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF1565C0),
                                  shape: BoxShape.circle),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folio,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1),
                                ),
                                Text(
                                  nombre,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: esPendiente ? naranja : const Color(0xFF1565C0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  estatus.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              if (tiempoEspera.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  tiempoEspera,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── LISTA DE PRODUCTOS ──
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: productos.map<Widget>((p) {
                          final String nombreProd =
                              p['nombre'] ?? 'Producto';
                          final int cantidad = p['cantidad'] ?? 1;
                          final String notas =
                          (p['notas'] ?? '').toString().trim();
                          final bool tieneNotas = notas.isNotEmpty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              // Fondo diferente si tiene notas especiales
                              color: tieneNotas
                                  ? Colors.yellow[900]!.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: tieneNotas
                                  ? Border.all(
                                  color: Colors.yellow[600]!,
                                  width: 2)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Cantidad en círculo grande
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: esPendiente
                                            ? naranja
                                            : const Color(0xFF1565C0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "x$cantidad",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        nombreProd,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                // ── NOTAS ESPECIALES ── muy destacadas
                                if (tieneNotas) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red[800],
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_rounded,
                                            color: Colors.yellow,
                                            size: 22),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            notas.toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                letterSpacing: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // ── BOTONES DE ACCIÓN ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          if (esPendiente)
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: naranja,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () =>
                                    _cambiarEstatus(doc.id, "En proceso"),
                                icon: const Icon(Icons.local_fire_department,
                                    size: 26),
                                label: const Text(
                                  "COCINAR",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          if (!esPendiente) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: verde,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () =>
                                    _cambiarEstatus(doc.id, "Listo"),
                                icon: const Icon(Icons.check_circle,
                                    size: 26),
                                label: const Text(
                                  "LISTO",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
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

// ─── PANEL ADMIN COMPLETO (MODO CAJA) ────────────────────────────────────────
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final Color azulUTPN = const Color(0xFF1565C0);
  final Color azulOscuro = const Color(0xFF0D47A1);

  String _filtroNombre = "";
  DateTime _fechaSeleccionada = DateTime.now();

  final _nCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  final _detCtrl = TextEditingController();

  XFile? _imagenWeb;
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;
  String? _categoriaSeleccionada;

  @override
  void initState() {
    super.initState();
    _registrarAdminToken();
  }

  @override
  void dispose() {
    _nCtrl.dispose();
    _pCtrl.dispose();
    _detCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarAdminToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        debugPrint("✅ Token admin guardado: $token");
      }
    } catch (e) {
      debugPrint("❌ Error al registrar token: $e");
    }
  }

  // ─── ESCANER QR ────────────────────────────────────────────────────────
  void _abrirEscanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("ESCANER DE PEDIDOS / ALUMNOS",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty &&
                      barcodes.first.rawValue != null) {
                    final String codigo = barcodes.first.rawValue!;
                    Navigator.pop(context);
                    _procesarCodigoQR(codigo);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarCodigoQR(String codigo) async {
    var pedidoSnap = await FirebaseFirestore.instance
        .collection('ordenes')
        .where('folio', isEqualTo: codigo)
        .limit(1)
        .get();
    if (pedidoSnap.docs.isNotEmpty) {
      _dialogoEntregaRapida(pedidoSnap.docs.first);
      return;
    }
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(codigo)
        .get();
    if (userDoc.exists) {
      _dialogoInfoUsuario(userDoc);
    } else {
      _msj("Código QR no registrado");
    }
  }

  // ─── VISTA PEDIDOS ──────────────────────────────────────────────────────
  Widget _vistaPedidos() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) =>
                setState(() => _filtroNombre = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Buscar por alumno...",
              prefixIcon: Icon(Icons.search, color: azulUTPN),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ordenes')
                .orderBy('fecha', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text("Error al cargar pedidos",
                          style: TextStyle(color: Colors.red[700])),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var docsActivos = snapshot.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                String est =
                (data['estatus'] ?? data['estado'] ?? "")
                    .toString()
                    .toLowerCase();
                return est == "pendiente" ||
                    est == "en proceso" ||
                    est == "listo" ||
                    est == "orden lista";
              }).toList();

              var filtrados = docsActivos.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String nombre = (data['nombreUsuario'] ??
                    data['nombreAlumno'] ??
                    data['nombre'] ??
                    "")
                    .toString()
                    .toLowerCase();
                return nombre.contains(_filtroNombre);
              }).toList();

              if (filtrados.isEmpty) {
                return const Center(
                    child: Text("No hay pedidos activos"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: filtrados.length,
                itemBuilder: (context, index) {
                  var doc = filtrados[index];
                  var orden = doc.data() as Map<String, dynamic>;
                  String status =
                  (orden['estatus'] ?? orden['estado'] ?? 'Pendiente')
                      .toString()
                      .toLowerCase();

                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: Icon(Icons.circle,
                          color: (status == 'listo' ||
                              status == 'orden lista')
                              ? Colors.green
                              : (status == 'en proceso'
                              ? Colors.blue
                              : Colors.orange),
                          size: 12),
                      title: Text(
                          orden['nombreUsuario'] ??
                              orden['nombreAlumno'] ??
                              'Usuario',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          "Folio: ${orden['folio']} • \$${orden['total']}"),
                      children: [
                        const Divider(),
                        ...(orden['productos'] as List).map((p) =>
                            ListTile(
                              dense: true,
                              title: Text(
                                  "${p['cantidad']}x ${p['nombre']}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle:
                              (p['notas'] != null && p['notas'] != "")
                                  ? Container(
                                padding: const EdgeInsets.all(5),
                                margin: const EdgeInsets.only(
                                    top: 5),
                                decoration: BoxDecoration(
                                    color: Colors.yellow[100],
                                    borderRadius:
                                    BorderRadius.circular(5)),
                                child: Text(
                                    "OJO: ${p['notas']}",
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 12)),
                              )
                                  : null,
                            )),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                            children: [
                              if (status == 'pendiente')
                                ElevatedButton(
                                    onPressed: () => _cambiarEstatus(
                                        doc.id, "En proceso"),
                                    child: const Text("COCINAR")),
                              if (status == 'en proceso')
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    onPressed: () => _cambiarEstatus(
                                        doc.id, "Listo"),
                                    child: const Text("LISTO")),
                              if (status == 'listo' ||
                                  status == 'orden lista')
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: azulOscuro),
                                    onPressed: () => _cambiarEstatus(
                                        doc.id, "Entregado"),
                                    child: const Text("ENTREGAR",
                                        style: TextStyle(
                                            color: Colors.white))),
                              IconButton(
                                  icon: const Icon(Icons.person_off,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _marcarNoRecogido(doc)),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── GESTIÓN DEL MENÚ ──────────────────────────────────────────────────
  Widget _vistaGestionMenu() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: azulUTPN,
        onPressed: _dialogoProducto,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NUEVO PRODUCTO",
            style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categorias')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, catSnapshot) {
          if (catSnapshot.hasError) {
            return Center(
              child: Text("Error al cargar categorías",
                  style: TextStyle(color: Colors.red[700])),
            );
          }
          if (!catSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: catSnapshot.data!.docs.length,
            itemBuilder: (context, i) {
              var catDoc = catSnapshot.data!.docs[i];
              var cat = catDoc.data() as Map<String, dynamic>;
              return ExpansionTile(
                title: Text(cat['nombre'] ?? "Sin nombre",
                    style:
                    const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  onPressed: () => _confirmarBorrarCategoria(
                      catDoc.id, cat['nombre']),
                ),
                children: [
                  _buildProductosPorCategoria(cat['nombre'] ?? "")
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmarBorrarCategoria(String id, String nombre) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Eliminar Categoría"),
          content: Text(
              "¿Borrar '$nombre'? Esto no borrará los productos, pero quedarán sin categoría."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CANCELAR")),
            ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('categorias')
                      .doc(id)
                      .delete();
                  Navigator.pop(c);
                },
                child: const Text("ELIMINAR")),
          ],
        ));
  }

  Widget _buildProductosPorCategoria(String categoria) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('categoria', isEqualTo: categoria)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return Column(
          children: snapshot.data!.docs.map((p) {
            var d = p.data() as Map<String, dynamic>;
            return ListTile(
              leading: d['imagenUrl'] != null
                  ? Image.network(d['imagenUrl'],
                  width: 45, height: 45, fit: BoxFit.cover)
                  : const Icon(Icons.fastfood),
              title: Text(d['nombre'] ?? "Producto"),
              subtitle:
              Text("\$${d['precio']} - ${d['detalle'] ?? ""}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                      value: d['disponibilidad'] ?? true,
                      onChanged: (v) =>
                          p.reference.update({'disponibilidad': v})),
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _dialogoEditarProducto(p)),
                  IconButton(
                      icon:
                      const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarEliminacion(
                          p.id, d['nombre'] ?? "")),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── CHATS DE SOPORTE ──────────────────────────────────────────────────
  Widget _vistaChatsSoporte() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .orderBy('fechaUltimoMensaje', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("Error al cargar chats",
                style: TextStyle(color: Colors.red[700])),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("No hay conversaciones activas"));
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            var chatDoc = snapshot.data!.docs[i];
            var chatData = chatDoc.data() as Map<String, dynamic>;
            String nombre = chatData['nombreUsuario'] ?? "Usuario";
            String ultimoMensaje = chatData['ultimoMensaje'] ?? "";
            String userId = chatDoc.id;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: azulUTPN,
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : "U",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(nombre,
                  style:
                  const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(ultimoMensaje,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete_sweep,
                    color: Colors.redAccent),
                onPressed: () =>
                    _confirmarBorrarChat(userId, nombre),
              ),
              onTap: () => _abrirChatDetalle(userId, nombre),
            );
          },
        );
      },
    );
  }

  void _confirmarBorrarChat(String userId, String nombre) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Limpiar Chat"),
        content:
        Text("¿Deseas eliminar todos los mensajes con $nombre?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("CANCELAR")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              onPressed: () async {
                var msjs = await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(userId)
                    .collection('mensajes')
                    .get();
                for (var doc in msjs.docs) {
                  await doc.reference.delete();
                }
                Navigator.pop(c);
                _msj("Chat de $nombre eliminado");
              },
              child: const Text("BORRAR TODO",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _abrirChatDetalle(String userId, String nombre) {
    final msgCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            AppBar(
                title: Text("Chat: $nombre"),
                backgroundColor: azulUTPN,
                foregroundColor: Colors.white),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(userId)
                    .collection('mensajes')
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  return ListView.builder(
                    reverse: true,
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (context, i) {
                      var mDoc = snap.data!.docs[i];
                      var m = mDoc.data() as Map<String, dynamic>;
                      bool isAdmin = m['enviadoPor'] == 'admin';
                      return Align(
                        alignment: isAdmin
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: isAdmin
                                  ? azulUTPN
                                  : Colors.grey[300],
                              borderRadius:
                              BorderRadius.circular(15)),
                          child: Text(m['texto'] ?? "",
                              style: TextStyle(
                                  color: isAdmin
                                      ? Colors.white
                                      : Colors.black)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: msgCtrl,
                          decoration: const InputDecoration(
                              hintText: "Escribir respuesta..."))),
                  IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.blue),
                      onPressed: () {
                        if (msgCtrl.text.isEmpty) return;
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(userId)
                            .collection('mensajes')
                            .add({
                          'texto': msgCtrl.text,
                          'enviadoPor': 'admin',
                          'fecha': FieldValue.serverTimestamp(),
                        });
                        msgCtrl.clear();
                      }),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ─── DEUDORES ──────────────────────────────────────────────────────────
  Widget _vistaDeudores() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("Error al cargar deudores",
                style: TextStyle(color: Colors.red[700])),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var deudores = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return data['Deuda'] != null && data['Deuda'] > 0;
        }).toList();

        if (deudores.isEmpty) {
          return const Center(
              child: Text("No hay alumnos con adeudos"));
        }

        return ListView.builder(
          itemCount: deudores.length,
          itemBuilder: (context, i) {
            var doc = deudores[i];
            var u = doc.data() as Map<String, dynamic>;
            bool estaBloqueado = u['bloqueado'] ?? false;

            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              child: ListTile(
                leading: Icon(
                    estaBloqueado
                        ? Icons.block
                        : Icons.warning_amber_rounded,
                    color: estaBloqueado ? Colors.black : Colors.red),
                title: Text(u['nombre'] ?? "Sin nombre",
                    style:
                    const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Adeudo: \$${u['Deuda']}",
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: !estaBloqueado,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.grey,
                        onChanged: (v) {
                          doc.reference.update({'bloqueado': !v});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: azulOscuro,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12)),
                        onPressed: () => _confirmarPago(doc),
                        child: const Text("PAGAR")),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarPago(DocumentSnapshot doc) {
    var u = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirmar Pago"),
        content: Text(
            "¿Marcar a ${u['nombre'] ?? 'este alumno'} como pagado?\n\nSe limpiará su adeudo de \$${u['Deuda']} y se desbloqueará su cuenta."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("CANCELAR")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green),
              onPressed: () {
                doc.reference.update({
                  'Deuda': 0,
                  'bloqueado': false,
                });
                Navigator.pop(c);
                _msj(
                    "Pago registrado. Cuenta de ${u['nombre'] ?? 'alumno'} desbloqueada.");
              },
              child: const Text("SÍ, CONFIRMAR",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // ─── REPORTES ──────────────────────────────────────────────────────────
  Widget _vistaReportes() {
    DateTime inicio = DateTime(_fechaSeleccionada.year,
        _fechaSeleccionada.month, _fechaSeleccionada.day);
    DateTime fin = inicio.add(const Duration(days: 1));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ordenes')
          .where('estatus', isEqualTo: 'Entregado')
          .where('fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text("Error al cargar reportes",
                style: TextStyle(color: Colors.red[700])),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        double total = 0;
        for (var d in snap.data!.docs) {
          var data = d.data() as Map<String, dynamic>;
          total += (data['total'] ?? 0);
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("VENTAS DEL DÍA",
                  style: TextStyle(color: azulUTPN, fontSize: 18)),
              Text("\$${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 45, fontWeight: FontWeight.bold)),
              Text("${snap.data!.docs.length} pedidos hoy"),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () async {
                    DateTime? p = await showDatePicker(
                        context: context,
                        initialDate: _fechaSeleccionada,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now());
                    if (p != null)
                      setState(() => _fechaSeleccionada = p);
                  },
                  child: const Text("CAMBIAR FECHA")),
            ],
          ),
        );
      },
    );
  }

  Widget _vistaCancelados() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ordenes')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("Error al cargar cancelados",
                style: TextStyle(color: Colors.red[700])),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var cancelados = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          String est = (data['estatus'] ?? data['estado'] ?? "")
              .toString()
              .toLowerCase()
              .trim();
          return est.contains("cancel") ||
              est.contains("no recogido");
        }).toList();

        if (cancelados.isEmpty) {
          return const Center(
              child: Text("No hay historial de cancelados"));
        }

        return ListView.builder(
          itemCount: cancelados.length,
          itemBuilder: (context, i) {
            var doc = cancelados[i];
            var data = doc.data() as Map<String, dynamic>;
            String nombre = data['nombreUsuario'] ??
                data['nombreAlumno'] ??
                'Usuario';
            String realStatus =
            (data['estatus'] ?? data['estado'] ?? "Cancelado")
                .toString();

            return ListTile(
              leading: Icon(
                  realStatus.toLowerCase().contains("recogido")
                      ? Icons.money_off
                      : Icons.cancel,
                  color: Colors.orange),
              title: Text(nombre,
                  style:
                  const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  "Estado: $realStatus\nFolio: ${data['folio'] ?? 'S/F'}"),
              trailing: Text("\$${data['total'] ?? '0'}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }

  // ─── AUXILIARES ────────────────────────────────────────────────────────
  void _cambiarEstatus(String id, String e) {
    FirebaseFirestore.instance
        .collection('ordenes')
        .doc(id)
        .update({'estatus': e, 'estado': e});
  }

  void _msj(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  void _marcarNoRecogido(QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    if (data['userId'] != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(data['userId'])
          .update({'Deuda': FieldValue.increment(20.0)});
    }
    doc.reference
        .update({'estatus': 'No Recogido', 'estado': 'No Recogido'});
  }

  void _dialogoEntregaRapida(QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Folio: ${data['folio']}"),
        content: Text(
            "¿Confirmar entrega para ${data['nombreUsuario'] ?? data['nombreAlumno']}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("NO")),
          ElevatedButton(
              onPressed: () {
                _cambiarEstatus(doc.id, "Entregado");
                Navigator.pop(c);
              },
              child: const Text("SÍ, ENTREGAR")),
        ],
      ),
    );
  }

  void _dialogoInfoUsuario(DocumentSnapshot userDoc) {
    var user = userDoc.data() as Map<String, dynamic>;
    String identificacion = user['matricula'] ??
        user['id_institucional'] ??
        user['matricula_id'] ??
        "Sin matrícula";
    String rol = user['rol'] ?? 'cliente';
    String etiqueta = (rol == 'admin') ? "ID Institucional" : "Matrícula";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(user['nombre'] ?? "Info"),
        content: Text(
            "$etiqueta: $identificacion\nDeuda: \$${user['Deuda'] ?? 0}"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("CERRAR"))
        ],
      ),
    );
  }

  void _seleccionarImagen(StateSetter setStateDS) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Cámara"),
            onTap: () async {
              Navigator.pop(ctx);
              final XFile? img =
              await _picker.pickImage(source: ImageSource.camera);
              if (img != null) setStateDS(() => _imagenWeb = img);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Galería"),
            onTap: () async {
              Navigator.pop(ctx);
              final XFile? img =
              await _picker.pickImage(source: ImageSource.gallery);
              if (img != null) setStateDS(() => _imagenWeb = img);
            },
          ),
        ],
      ),
    );
  }

  void _dialogoNuevaCategoria(StateSetter setStateDS) {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nueva Categoría"),
        content: TextField(
            controller: catCtrl,
            decoration:
            const InputDecoration(hintText: "Nombre de categoría")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("CERRAR")),
          ElevatedButton(
              onPressed: () async {
                if (catCtrl.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('categorias')
                      .add({'nombre': catCtrl.text});
                  setStateDS(
                          () => _categoriaSeleccionada = catCtrl.text);
                  Navigator.pop(c);
                }
              },
              child: const Text("AGREGAR")),
        ],
      ),
    );
  }

  void _dialogoProducto() {
    _nCtrl.clear();
    _pCtrl.clear();
    _detCtrl.clear();
    _imagenWeb = null;
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDS) => AlertDialog(
          title: const Text("Nuevo Producto"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _seleccionarImagen(setStateDS),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10)),
                    child: _imagenWeb == null
                        ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40),
                          Text("Subir Foto")
                        ])
                        : (kIsWeb
                        ? Image.network(_imagenWeb!.path)
                        : Image.file(File(_imagenWeb!.path),
                        fit: BoxFit.cover)),
                  ),
                ),
                TextField(
                    controller: _nCtrl,
                    decoration:
                    const InputDecoration(labelText: "Nombre")),
                TextField(
                    controller: _pCtrl,
                    decoration: const InputDecoration(
                        labelText: "Precio", prefixText: "\$")),
                TextField(
                    controller: _detCtrl,
                    decoration: const InputDecoration(
                        labelText: "Detalle (Descripción)")),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('categorias')
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox();
                          return DropdownButton<String>(
                            value: _categoriaSeleccionada,
                            isExpanded: true,
                            hint: const Text("Categoría"),
                            onChanged: (v) => setStateDS(
                                    () => _categoriaSeleccionada = v),
                            items: snap.data!.docs.map((d) {
                              var catData =
                              d.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                  value: catData['nombre'].toString(),
                                  child: Text(catData['nombre']));
                            }).toList(),
                          );
                        },
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Colors.green),
                        onPressed: () =>
                            _dialogoNuevaCategoria(setStateDS)),
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CERRAR")),
            ElevatedButton(
                onPressed:
                _subiendo ? null : () => _guardarProducto(c),
                child:
                Text(_subiendo ? "Subiendo..." : "GUARDAR")),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarProducto(BuildContext ctx) async {
    if (_nCtrl.text.isEmpty ||
        _imagenWeb == null ||
        _categoriaSeleccionada == null) {
      _msj("Completa todos los campos y la foto");
      return;
    }
    setState(() => _subiendo = true);
    try {
      String path =
          "productos/${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = FirebaseStorage.instance.ref().child(path);
      kIsWeb
          ? await ref.putData(await _imagenWeb!.readAsBytes())
          : await ref.putFile(File(_imagenWeb!.path));
      String url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('productos').add({
        'nombre': _nCtrl.text,
        'precio': double.parse(_pCtrl.text),
        'detalle': _detCtrl.text,
        'categoria': _categoriaSeleccionada,
        'imagenUrl': url,
        'disponibilidad': true
      });
      Navigator.pop(ctx);
      _msj("Producto agregado con éxito");
    } catch (e) {
      _msj("Error al guardar: $e");
    }
    setState(() => _subiendo = false);
  }

  void _dialogoEditarProducto(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    final nE = TextEditingController(text: data['nombre']);
    final pE =
    TextEditingController(text: data['precio'].toString());
    final dE =
    TextEditingController(text: data['detalle'] ?? "");
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Editar"),
          content:
          Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nE,
                decoration:
                const InputDecoration(labelText: "Nombre")),
            TextField(
                controller: pE,
                decoration:
                const InputDecoration(labelText: "Precio")),
            TextField(
                controller: dE,
                decoration:
                const InputDecoration(labelText: "Detalle")),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CANC")),
            ElevatedButton(
                onPressed: () {
                  doc.reference.update({
                    'nombre': nE.text,
                    'precio': double.parse(pE.text),
                    'detalle': dE.text
                  });
                  Navigator.pop(c);
                },
                child: const Text("OK")),
          ],
        ));
  }

  void _confirmarEliminacion(String id, String n) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Eliminar"),
          content: Text("¿Borrar $n?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("NO")),
            ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('productos')
                      .doc(id)
                      .delete();
                  Navigator.pop(c);
                },
                child: const Text("SÍ")),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ADMIN CAFETERÍA"),
          backgroundColor: azulUTPN,
          foregroundColor: Colors.white,
          actions: [
            // Botón para volver al selector de modo
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: "Cambiar modo",
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminModeSelectorPage()),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _abrirEscanner,
                tooltip: "Escanear QR"),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "PEDIDOS", icon: Icon(Icons.list_alt)),
              Tab(text: "CHATS", icon: Icon(Icons.chat)),
              Tab(text: "DEUDORES", icon: Icon(Icons.money_off)),
              Tab(text: "MENÚ", icon: Icon(Icons.restaurant_menu)),
              Tab(text: "VENTAS", icon: Icon(Icons.bar_chart)),
              Tab(text: "CANCELADOS", icon: Icon(Icons.cancel)),
            ],
          ),
        ),
        body: TabBarView(children: [
          _vistaPedidos(),
          _vistaChatsSoporte(),
          _vistaDeudores(),
          _vistaGestionMenu(),
          _vistaReportes(),
          _vistaCancelados(),
        ]),
      ),
    );
  }
}