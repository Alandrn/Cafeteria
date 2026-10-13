import 'admin_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Colores Institucionales UTPN
  final Color azulUTPN = const Color(0xFF1565C0);
  final Color azulOscuro = const Color(0xFF0D47A1);

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _recordarCorreo = false;
  List<String> _historialCorreos = [];

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  void _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historialCorreos = prefs.getStringList('historial_correos') ?? [];
      _recordarCorreo = prefs.getBool('remember_me') ?? false;

      if (_recordarCorreo && _historialCorreos.isNotEmpty) {
        _emailController.text = _historialCorreos.first;
      }
    });
  }

  void _gestionarPersistencia(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _recordarCorreo);

    if (_recordarCorreo) {
      if (!_historialCorreos.contains(email)) {
        _historialCorreos.insert(0, email);
        if (_historialCorreos.length > 3) _historialCorreos.removeLast();
        await prefs.setStringList('historial_correos', _historialCorreos);
      }
    } else {
      await prefs.remove('historial_correos');
      setState(() => _historialCorreos = []);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _error("Por favor, ingresa tus credenciales.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        _error("Correo no verificado. Revisa tu bandeja de entrada.");
        return;
      }

      _gestionarPersistencia(email);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        String rol = data['rol'] ?? 'cliente';

        if (rol == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminModeSelectorPage()),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _error("Usuario no registrado en la base de datos.");
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') _error("No existe cuenta con este correo.");
      else if (e.code == 'wrong-password') _error("Contraseña incorrecta.");
      else _error("Error al iniciar sesión. Intenta de nuevo.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _error(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msj),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // El color azul llegará hasta arriba
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // --- HEADER CON LOGO (CORREGIDO PARA EVITAR OVERFLOW) ---
              Container(
                height: MediaQuery.of(context).size.height * 0.40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: azulUTPN,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(60),
                    bottomRight: Radius.circular(60),
                  ),
                  gradient: LinearGradient(
                    colors: [azulUTPN, azulOscuro],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
                      ),
                      child: Image.asset(
                        'assets/logo.png', // Logo del Coyote
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.restaurant, size: 70, color: azulUTPN),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text("UNIVERSIDAD TECNOLÓGICA",
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const Text("PASO DEL NORTE",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("SISTEMA DE CAFETERÍA",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  children: [
                    const Text("Bienvenido", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 20),

                    // CAMPO EMAIL
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Correo Institucional",
                        hintText: "ejemplo@utpn.edu.mx",
                        prefixIcon: Icon(Icons.person_outline, color: azulUTPN),
                        suffixIcon: _historialCorreos.isNotEmpty
                            ? PopupMenuButton<String>(
                          icon: const Icon(Icons.history),
                          onSelected: (val) => setState(() => _emailController.text = val),
                          itemBuilder: (context) => _historialCorreos.map((e) =>
                              PopupMenuItem(value: e, child: Text(e))).toList(),
                        )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // CAMPO CONTRASEÑA
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        prefixIcon: Icon(Icons.lock_outline, color: azulUTPN),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),

                    // OPCIÓN RECORDAR DATOS
                    CheckboxListTile(
                      title: const Text("Recordar mis datos", style: TextStyle(fontSize: 14)),
                      value: _recordarCorreo,
                      activeColor: azulUTPN,
                      onChanged: (val) => setState(() => _recordarCorreo = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 10),

                    // BOTÓN ENTRAR
                    _isLoading
                        ? CircularProgressIndicator(color: azulUTPN)
                        : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulUTPN,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                        ),
                        child: const Text("INICIAR SESIÓN",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // REGISTRO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("¿Aún no tienes cuenta?"),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          child: Text("Regístrate aquí",
                              style: TextStyle(color: azulUTPN, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20), // Espacio final
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}