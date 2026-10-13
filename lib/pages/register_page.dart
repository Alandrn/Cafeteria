import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _idController = TextEditingController();

  final Color azulUTPN = const Color(0xFF1565C0);
  bool _isLoading = false;

  Future<void> _registrar() async {
    final email = _emailController.text.trim();
    final nombre = _nombreController.text.trim();
    final idUsuario = _idController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Validaciones básicas
    if (nombre.isEmpty || idUsuario.isEmpty || email.isEmpty || password.isEmpty) {
      _error("Por favor, completa todos los campos.");
      return;
    }

    if (!email.endsWith('@utpn.edu.mx') && email != 'administradorcafutpn@gmail.com') {
      _error("Debes usar un correo institucional válido.");
      return;
    }

    if (password.length < 6) {
      _error("La contraseña debe tener al menos 6 caracteres.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Crear usuario en Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 3. Obtener Token para Notificaciones (Push)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {
        // Ignorar si falla el token, no debe detener el registro
      }

      // 4. Determinar Rol automáticamente
      String rolAsignado = (email == 'administradorcafutpn@gmail.com') ? 'admin' : 'cliente';

      // 5. Guardar Perfil Completo en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'nombre': nombre,
        'email': email,
        'id_institucional': idUsuario,
        'rol': rolAsignado,
        'Deuda': 0.0, // Inicializamos sin deuda
        'fcmToken': fcmToken ?? "",
        'fecha_registro': FieldValue.serverTimestamp(),
      });

      // 6. Enviar verificación
      await userCredential.user!.sendEmailVerification();

      _success("¡Registro exitoso! Verifica tu bandeja de entrada.");

      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _error("Este correo ya está en uso.");
      } else {
        _error("Error: ${e.message}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _error(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msj), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
    );
  }

  void _success(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msj), backgroundColor: Colors.green[700], behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("REGISTRO UTPN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: azulUTPN,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Icon(Icons.account_circle, size: 80, color: azulUTPN.withOpacity(0.8)),
            const SizedBox(height: 30),

            _buildField(_nombreController, "Nombre Completo", Icons.person),
            const SizedBox(height: 15),
            _buildField(_idController, "Matrícula / ID", Icons.badge, isNumber: true),
            const SizedBox(height: 15),
            _buildField(_emailController, "Correo Institucional", Icons.email, isEmail: true),
            const SizedBox(height: 15),
            _buildField(_passwordController, "Contraseña", Icons.lock, isPassword: true),

            const SizedBox(height: 40),

            _isLoading
                ? CircularProgressIndicator(color: azulUTPN)
                : SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _registrar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulUTPN,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("CREAR CUENTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {bool isPassword = false, bool isEmail = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : (isNumber ? TextInputType.number : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: azulUTPN),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}