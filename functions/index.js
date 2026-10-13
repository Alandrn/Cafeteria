const { setGlobalOptions } = require("firebase-functions");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

// ─── HELPER: Obtener todos los tokens de admins ───────────────────────────────
async function obtenerTokensAdmin() {
  const adminsSnap = await admin.firestore()
    .collection("users")
    .where("rol", "==", "admin")
    .get();

  const tokens = [];
  adminsSnap.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (token) tokens.push(token);
  });
  return tokens;
}

// ─── HELPER: Enviar a múltiples tokens ───────────────────────────────────────
async function enviarATokens(tokens, mensaje) {
  const resultados = await Promise.allSettled(
    tokens.map((token) =>
      admin.messaging().send({ ...mensaje, token })
    )
  );
  resultados.forEach((r, i) => {
    if (r.status === "fulfilled") {
      console.log(`✅ Enviado a token ${i}:`, r.value);
    } else {
      console.error(`❌ Error en token ${i}:`, r.reason);
    }
  });
}

// ─── 1. NOTIFICACIÓN AL ADMIN: NUEVO PEDIDO ──────────────────────────────────
exports.notificarAdminNuevoPedido = onDocumentCreated(
  "ordenes/{ordenId}",
  async (event) => {
    const pedido = event.data.data();
    if (!pedido) return null;

    const nombre = pedido.nombreUsuario ?? "Alumno";
    const folio = pedido.folio ?? "S/F";
    const total = pedido.total ? `$${Number(pedido.total).toFixed(2)}` : "$0.00";
    const productos = pedido.productos ?? [];

    // Construimos la lista de productos para el texto largo
    const listaProductos = productos
      .map((p) => `• ${p.cantidad}x ${p.nombre}`)
      .join("\n");

    const cuerpoCorto = `${nombre} — ${productos.length} producto(s) — ${total}`;
    const cuerpoLargo = `👤 Alumno: ${nombre}\n📋 Folio: ${folio}\n\n${listaProductos}\n\n💰 Total: ${total}`;

    const tokens = await obtenerTokensAdmin();
    if (tokens.length === 0) {
      console.log("No hay admins con fcmToken registrado.");
      return null;
    }

    const mensaje = {
      notification: {
        title: "🛎️ ¡Nuevo pedido recibido!",
        body: cuerpoCorto,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channel_id: "admin_pedidos_channel",
          priority: "max",
          default_vibrate_timings: true,
          default_sound: true,
          color: "#1565C0",
          body: cuerpoLargo,
          actions: [
            { action: "ver_pedidos", title: "VER PEDIDOS" },
            { action: "cerrar", title: "CERRAR" },
          ],
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
            alert: {
              title: "🛎️ ¡Nuevo pedido recibido!",
              body: cuerpoLargo,
            },
          },
        },
        headers: { "apns-priority": "10" },
      },
      data: {
        tipo: "nuevo_pedido",
        folio: folio,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    return enviarATokens(tokens, mensaje);
  }
);

// ─── 2. NOTIFICACIÓN AL ADMIN: NUEVO MENSAJE DE CHAT ─────────────────────────
exports.notificarAdminNuevoMensaje = onDocumentCreated(
  "chats/{userId}/mensajes/{mensajeId}",
  async (event) => {
    const mensaje = event.data.data();
    if (!mensaje) return null;

    // Solo notificamos mensajes del cliente, no del admin
    if (mensaje.enviadoPor !== "cliente") return null;

    const userId = event.params.userId;
    const texto = mensaje.texto ?? "Nuevo mensaje";

    // Obtenemos el nombre del usuario
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const nombreUsuario = userDoc.exists ? (userDoc.data().nombre ?? "Usuario") : "Usuario";

    const tokens = await obtenerTokensAdmin();
    if (tokens.length === 0) return null;

    const mensajeFCM = {
      notification: {
        title: `💬 Mensaje de ${nombreUsuario}`,
        body: texto,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channel_id: "admin_chat_channel",
          priority: "max",
          default_vibrate_timings: true,
          default_sound: true,
          color: "#1565C0",
          actions: [
            { action: "ver_chat", title: "RESPONDER" },
            { action: "cerrar", title: "CERRAR" },
          ],
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
            alert: {
              title: `💬 Mensaje de ${nombreUsuario}`,
              body: texto,
            },
          },
        },
        headers: { "apns-priority": "10" },
      },
      data: {
        tipo: "nuevo_mensaje",
        userId: userId,
        nombreUsuario: nombreUsuario,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    return enviarATokens(tokens, mensajeFCM);
  }
);

// ─── 3. NOTIFICACIÓN AL USUARIO: CAMBIO DE ESTATUS ───────────────────────────
exports.notificarCambioOrden = onDocumentUpdated(
  "ordenes/{ordenId}",
  async (event) => {
    const antes = event.data.before.data();
    const despues = event.data.after.data();

    if (antes.estatus === despues.estatus) return null;

    const nuevoEstatus = despues.estatus;
    const userId = despues.userId;
    const folio = despues.folio ?? "S/F";
    const total = despues.total ? `$${Number(despues.total).toFixed(2)}` : "";

    const estatusNotificables = ["Listo", "Orden Lista", "En proceso", "Cancelado"];
    if (!estatusNotificables.includes(nuevoEstatus)) return null;

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) return null;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return null;

    let titulo = "";
    let cuerpoCorto = "";
    let cuerpoLargo = "";

    switch (nuevoEstatus) {
      case "Listo":
      case "Orden Lista":
        titulo = "🍽️ ¡Tu pedido está listo!";
        cuerpoCorto = `Folio ${folio} — Pasa a recogerlo.`;
        cuerpoLargo = `Tu orden con folio ${folio} ya está lista en la ventanilla.\n\nTotal: ${total}\n\n¡Date prisa antes de que se enfríe! 🔥`;
        break;
      case "En proceso":
        titulo = "👨‍🍳 ¡Estamos cocinando tu orden!";
        cuerpoCorto = `Folio ${folio} — En preparación.`;
        cuerpoLargo = `Tu pedido con folio ${folio} ya está en manos de nuestros cocineros.\n\nTotal: ${total}\n\nTe avisaremos cuando esté listo. 🍳`;
        break;
      case "Cancelado":
        titulo = "❌ Pedido cancelado";
        cuerpoCorto = `Folio ${folio} — Cancelado.`;
        cuerpoLargo = `Tu pedido con folio ${folio} fue cancelado.\n\nSi tienes dudas, contáctanos por el chat de soporte.`;
        break;
    }

    const mensajeFCM = {
      token: fcmToken,
      notification: { title: titulo, body: cuerpoCorto },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channel_id: "pedidos_channel",
          priority: "max",
          default_vibrate_timings: true,
          default_sound: true,
          color: "#1565C0",
          body: cuerpoLargo,
          actions: [
            { action: "ver_pedido", title: "VER PEDIDO" },
            { action: "cerrar", title: "CERRAR" },
          ],
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
            alert: { title: titulo, body: cuerpoLargo },
          },
        },
        headers: { "apns-priority": "10" },
      },
      data: {
        folio: folio,
        estatus: nuevoEstatus,
        tipo: "cambio_orden",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    try {
      const response = await admin.messaging().send(mensajeFCM);
      console.log(`✅ Notificación enviada a usuario ${userId}:`, response);
      return response;
    } catch (error) {
      console.error(`❌ Error:`, error);
      return null;
    }
  }
);