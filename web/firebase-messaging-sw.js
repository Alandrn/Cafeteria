importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Pega aquí la configuración de tu proyecto de Firebase (la sacas de la consola de Firebase)
firebase.initializeApp({
  apiKey: "TU_API_KEY",
  authDomain: "tu-proyecto.firebaseapp.com",
  projectId: "tu-proyecto",
  storageBucket: "tu-proyecto.appspot.com",
  messagingSenderId: "TU_SENDER_ID",
  appId: "TU_APP_ID"
});

const messaging = firebase.messaging();

// Manejador en segundo plano para la Web
messaging.onBackgroundMessage((payload) => {
  console.log('Mensaje recibido en segundo plano ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/firebase-logo.png' // Opcional: un icono en tu carpeta web
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});