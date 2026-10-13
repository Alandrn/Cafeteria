import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/barra_moverse.dart';
import 'pages/admin_page.dart';
import 'pages/categoria_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── CANAL USUARIOS: cambios de estatus ──────────────────────────────────────
const AndroidNotificationChannel pedidosChannel = AndroidNotificationChannel(
  'pedidos_channel',
  'Pedidos Cafetería',
  description: 'Notificaciones de estado de tus pedidos',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

// ─── CANAL ADMIN: nuevos pedidos ─────────────────────────────────────────────
const AndroidNotificationChannel adminPedidosChannel = AndroidNotificationChannel(
  'admin_pedidos_channel',
  'Nuevos Pedidos (Admin)',
  description: 'Alerta al admin cuando llega un nuevo pedido',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

// ─── CANAL ADMIN: mensajes de chat ───────────────────────────────────────────
const AndroidNotificationChannel adminChatChannel = AndroidNotificationChannel(
  'admin_chat_channel',
  'Mensajes de Soporte (Admin)',
  description: 'Alerta al admin cuando un alumno envía un mensaje',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

// ─── MANEJADOR EN SEGUNDO PLANO ──────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _mostrarNotificacionLocal(message);
}

// ─── MOSTRAR NOTIFICACIÓN LOCAL ENRIQUECIDA ───────────────────────────────────
Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  final String titulo = notification.title ?? "";
  final String cuerpo = notification.body ?? "";
  final String tipo = message.data['tipo'] ?? "";

  // Seleccionamos el canal según el tipo de notificación
  String channelId;
  String channelName;
  List<AndroidNotificationAction> acciones;

  if (tipo == "nuevo_pedido") {
    channelId = adminPedidosChannel.id;
    channelName = adminPedidosChannel.name;
    acciones = const [
      AndroidNotificationAction(
        'ver_pedidos',
        'VER PEDIDOS',
        showsUserInterface: true,
        cancelNotification: true,
      ),
      AndroidNotificationAction('cerrar', 'CERRAR', cancelNotification: true),
    ];
  } else if (tipo == "nuevo_mensaje") {
    channelId = adminChatChannel.id;
    channelName = adminChatChannel.name;
    acciones = const [
      AndroidNotificationAction(
        'ver_chat',
        'RESPONDER',
        showsUserInterface: true,
        cancelNotification: true,
      ),
      AndroidNotificationAction('cerrar', 'CERRAR', cancelNotification: true),
    ];
  } else {
    // Notificación de cambio de estatus al usuario
    channelId = pedidosChannel.id;
    channelName = pedidosChannel.name;
    acciones = const [
      AndroidNotificationAction(
        'ver_pedido',
        'VER PEDIDO',
        showsUserInterface: true,
        cancelNotification: true,
      ),
      AndroidNotificationAction('cerrar', 'CERRAR', cancelNotification: true),
    ];
  }

  final BigTextStyleInformation bigText = BigTextStyleInformation(
    cuerpo,
    contentTitle: titulo,
    summaryText: 'UTPN Cafetería',
  );

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    color: const Color(0xFF1565C0),
    colorized: true,
    styleInformation: bigText,
    actions: acciones,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    titulo,
    cuerpo,
    NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: tipo == "nuevo_mensaje"
        ? message.data['userId']
        : message.data['folio'],
  );
}

// ─── NAVEGACIÓN AL TOCAR LA NOTIFICACIÓN ─────────────────────────────────────
void _manejarToque(NotificationResponse response) {
  final String? actionId = response.actionId;
  final String? payload = response.payload;

  if (actionId == 'ver_pedidos' || actionId == null && payload != null) {
    navigatorKey.currentState?.pushNamed('/home');
  } else if (actionId == 'ver_chat') {
    // Navega a la pestaña de chats del admin
    navigatorKey.currentState?.pushNamed('/admin');
  }
}

@pragma('vm:entry-point')
void _manejarToqueBackground(NotificationResponse response) {
  // El navigatorKey lo manejará cuando la app se abra
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    criticalAlert: true,
  );

  // ─── CREAR LOS 3 CANALES ANDROID ─────────────────────────────────────────
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(pedidosChannel);
  await androidPlugin?.createNotificationChannel(adminPedidosChannel);
  await androidPlugin?.createNotificationChannel(adminChatChannel);

  // ─── INICIALIZACIÓN DEL PLUGIN ────────────────────────────────────────────
  const AndroidInitializationSettings initAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initAndroid, iOS: initIOS),
    onDidReceiveNotificationResponse: _manejarToque,
    onDidReceiveBackgroundNotificationResponse: _manejarToqueBackground,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ─── APP EN PRIMER PLANO ──────────────────────────────────────────────────
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _mostrarNotificacionLocal(message);
  });

  // ─── APP CERRADA → al tocar la notificación ───────────────────────────────
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(const Duration(seconds: 1), () {
      final tipo = initialMessage.data['tipo'] ?? '';
      if (tipo == 'nuevo_mensaje') {
        navigatorKey.currentState?.pushNamed('/admin');
      } else {
        navigatorKey.currentState?.pushNamed('/home');
      }
    });
  }

  // ─── APP EN BACKGROUND → al tocar la notificación ────────────────────────
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final tipo = message.data['tipo'] ?? '';
    if (tipo == 'nuevo_mensaje') {
      navigatorKey.currentState?.pushNamed('/admin');
    } else {
      navigatorKey.currentState?.pushNamed('/home');
    }
  });

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseFirestore.instance.settings =
  const Settings(persistenceEnabled: false);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UTPN Food',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (userSnap.hasData && userSnap.data!.exists) {
                  final data =
                  userSnap.data!.data() as Map<String, dynamic>;
                  if (data['rol'] == 'admin') return const AdminPage();
                }
                return const BarraMoverse();
              },
            );
          }
          return const LoginPage();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const BarraMoverse(),
        '/admin': (context) => const AdminPage(),
        '/categoria': (context) => const CategoriaPage(),
      },
    );
  }
}