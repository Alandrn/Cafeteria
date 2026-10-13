import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> cargarProductosIniciales() async {
  final productos = [
    {
      "nombre": "Burrito de frijoles",
      "precio": 30.0,
      "categoria": "Comida",
      "imagenUrl": "https://firebasestorage.googleapis.com/tu-url-burrito.jpg"
    },
    {
      "nombre": "Torta de milanesa",
      "precio": 45.0,
      "categoria": "Comida",
      "imagenUrl": "https://firebasestorage.googleapis.com/tu-url-torta.jpg"
    },
    {
      "nombre": "Agua fresca de jamaica",
      "precio": 15.0,
      "categoria": "Bebidas",
      "imagenUrl": "https://firebasestorage.googleapis.com/tu-url-jamaica.jpg"
    },
    {
      "nombre": "Pastel de chocolate",
      "precio": 50.0,
      "categoria": "Postres",
      "imagenUrl": "https://firebasestorage.googleapis.com/tu-url-pastel.jpg"
    },
  ];

  for (var producto in productos) {
    await FirebaseFirestore.instance.collection('productos').add(producto);
  }

  print("✅ Productos iniciales cargados en Firestore");
}