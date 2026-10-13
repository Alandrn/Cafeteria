import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatUsuarioPage extends StatefulWidget {
  const ChatUsuarioPage({super.key});

  @override
  State<ChatUsuarioPage> createState() => _ChatUsuarioPageState();
}

class _ChatUsuarioPageState extends State<ChatUsuarioPage> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color azulUTPN = const Color(0xFF1565C0);
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  // ✅ CORRECCIÓN: se lee el nombre real del alumno desde Firestore (users/{uid}/nombre)
  // en lugar de depender de displayName de Auth que casi siempre es null,
  // lo que causaba que en el chat del admin apareciera "Usuario UTPN" para todos.
  Future<String> _obtenerNombreReal() async {
    if (uid == null) return "Usuario UTPN";
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['nombre'] ?? "Usuario UTPN";
    } catch (_) {
      return "Usuario UTPN";
    }
  }

  void _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty || uid == null) return;

    final texto = _mensajeController.text.trim();
    _mensajeController.clear();

    // Primero enviamos el mensaje para que sea instantáneo
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(uid)
        .collection('mensajes')
        .add({
      'texto': texto,
      'enviadoPor': 'cliente',
      'fecha': FieldValue.serverTimestamp(),
      'leido': false,
    });

    // Luego actualizamos el documento raíz con el nombre real
    final nombreReal = await _obtenerNombreReal();
    await FirebaseFirestore.instance.collection('chats').doc(uid).set({
      'ultimoMensaje': texto,
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
      'usuarioId': uid,
      // ✅ CORRECCIÓN: ahora usa el nombre real leído de Firestore
      'nombreUsuario': nombreReal,
      'pendienteAdmin': true,
    }, SetOptions(merge: true));

    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text("SOPORTE CAFETERÍA",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(uid)
                  .collection('mensajes')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error al cargar mensajes"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mensajes = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(15),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg =
                    mensajes[index].data() as Map<String, dynamic>;
                    bool esMio = msg['enviadoPor'] == 'cliente';
                    return _buildBurbuja(msg['texto'], esMio, msg['fecha']);
                  },
                );
              },
            ),
          ),
          _buildInputMensaje(),
        ],
      ),
    );
  }

  Widget _buildBurbuja(String texto, bool esMio, dynamic fecha) {
    String hora = "";
    if (fecha != null) {
      DateTime dt = (fecha as Timestamp).toDate();
      hora = DateFormat('hh:mm a').format(dt);
    }

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: esMio ? azulUTPN : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(esMio ? 15 : 0),
            bottomRight: Radius.circular(esMio ? 0 : 15),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
          ],
        ),
        child: Column(
          crossAxisAlignment:
          esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(texto,
                style: TextStyle(
                    color: esMio ? Colors.white : Colors.black87,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(hora,
                style: TextStyle(
                    color: esMio ? Colors.white70 : Colors.black45,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputMensaje() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 10)
          ]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _mensajeController,
              decoration: InputDecoration(
                hintText: "Escribe tu duda aquí...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: azulUTPN,
            child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _enviarMensaje),
          ),
        ],
      ),
    );
  }
}