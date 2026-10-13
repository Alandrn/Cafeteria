import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vibration/vibration.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color azulUTPN = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _escucharPedidosRealTime();
  }

  void _escucharPedidosRealTime() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('ordenes')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) return;

          String estatus = data['estatus'] ?? "";
          String folio = data['folio'] ?? "---";

          if (estatus == 'Orden Lista' || estatus == 'Listo') {
            _notificarAccion(folio, "¡TU PEDIDO ESTÁ LISTO!", Colors.green);
          } else if (estatus == 'No recogido') {
            _notificarAccion(folio, "Aviso: Pedido no recogido.", Colors.orange);
          }
        }
      }
    });
  }

  void _notificarAccion(String folio, String mensaje, Color color) async {
    if (!mounted) return;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$mensaje (Folio: $folio)"),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _verificarYEntrarAlMenu() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        num deuda = data['Deuda'] ?? 0;
        bool bloqueado = data['bloqueado'] ?? false;

        if (deuda > 0 || bloqueado == true) {
          if (!mounted) return;
          _mostrarAlertaBloqueo(deuda);
          return;
        }
      }

      // ✅ CORRECCIÓN: era !mounted (nunca navegaba), ahora es mounted
      if (mounted) Navigator.pushNamed(context, '/menu');
    } catch (e) {
      debugPrint("Error al verificar deuda: $e");
    }
  }

  void _mostrarAlertaBloqueo(num deuda) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.report_problem_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("AVISO DE ADEUDO",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            "No puedes realizar nuevos pedidos porque presentas un adeudo de \$$deuda.\n\nPor favor acude a caja para liquidar."),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("UTPN CAFETERÍA",
            style:
            TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () =>
                  Navigator.pushNamed(context, '/mis_pedidos')),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
            child: Text("Pedidos en curso",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: azulUTPN)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ordenes')
                  .where('userId', isEqualTo: user?.uid)
                  .where('estatus', whereIn: [
                'Pendiente',
                'En proceso',
                'Listo',
                'Orden Lista'
              ])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: azulUTPN));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No tienes pedidos activos ahora",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) =>
                      TarjetaPedido(orden: snapshot.data!.docs[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _verificarYEntrarAlMenu,
                icon: const Icon(Icons.restaurant_menu_rounded,
                    color: Colors.white),
                label: const Text("ORDENAR AHORA",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulUTPN,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TarjetaPedido extends StatelessWidget {
  final QueryDocumentSnapshot orden;
  const TarjetaPedido({super.key, required this.orden});

  @override
  Widget build(BuildContext context) {
    final data = orden.data() as Map<String, dynamic>;
    String estatus = data['estatus'] ?? 'Pendiente';
    bool esListo = estatus == "Orden Lista" || estatus == "Listo";
    final Color azulUTPN = const Color(0xFF1565C0);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: esListo ? Colors.green : Colors.grey.shade200, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor:
          esListo ? Colors.green[50] : Colors.orange[50],
          radius: 25,
          child: Icon(
              esListo
                  ? Icons.stars_rounded
                  : Icons.schedule_rounded,
              color: esListo ? Colors.green : Colors.orange,
              size: 30),
        ),
        title: Text("Folio: ${data['folio'] ?? '---'}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(estatus.toUpperCase(),
              style: TextStyle(
                  color: esListo ? Colors.green[700] : azulUTPN,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
        trailing: estatus == 'Pendiente'
            ? IconButton(
          icon:
          const Icon(Icons.cancel_outlined, color: Colors.red),
          onPressed: () => _cancelarPedido(context),
        )
            : const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: Colors.grey),
      ),
    );
  }

  void _cancelarPedido(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Cancelar Pedido?"),
        content: const Text(
            "Si el personal ya empezó a cocinar, esta opción podría deshabilitarse."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("NO")),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('ordenes')
                    .doc(orden.id)
                    .update({'estatus': 'Cancelado'});
                Navigator.pop(context);
              },
              child: const Text("SÍ, CANCELAR",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
