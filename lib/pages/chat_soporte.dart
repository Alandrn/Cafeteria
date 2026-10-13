import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatSoportePage extends StatelessWidget {
  const ChatSoportePage({super.key});

  final Color azulUTPN = const Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final TextEditingController msgController = TextEditingController();
    // ScrollController para asegurar que el chat siempre se vea bien al abrir el teclado
    final ScrollController scrollController = ScrollController();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("SOPORTE CAFETERÍA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(user?.uid)
                  .collection('mensajes')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error al cargar mensajes"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final msgs = snapshot.data!.docs;

                return ListView.builder(
                  controller: scrollController,
                  reverse: true,
                  itemCount: msgs.length,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemBuilder: (context, index) {
                    final m = msgs[index].data() as Map<String, dynamic>;
                    // IMPORTANTE: El Admin envía como 'admin', el usuario como 'cliente'
                    bool esMio = m['enviadoPor'] == 'cliente';

                    return Align(
                      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                            color: esMio ? azulUTPN : Colors.grey[100],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: Radius.circular(esMio ? 15 : 0),
                              bottomRight: Radius.circular(esMio ? 0 : 15),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
                            ]
                        ),
                        child: Text(
                            m['texto'] ?? "",
                            style: TextStyle(
                                color: esMio ? Colors.white : Colors.black87,
                                fontSize: 15
                            )
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Área de entrada de texto mejorada
          Container(
            padding: EdgeInsets.only(
                left: 15, right: 15, top: 10,
                bottom: MediaQuery.of(context).padding.bottom + 10
            ),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: msgController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Escribe tu duda...",
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[200]!)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: azulUTPN,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () async {
                      String texto = msgController.text.trim();
                      if (texto.isEmpty) return;

                      msgController.clear(); // Limpiamos rápido para dar sensación de velocidad

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(user?.uid)
                          .collection('mensajes')
                          .add({
                        'texto': texto,
                        'enviadoPor': 'cliente',
                        'fecha': FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}