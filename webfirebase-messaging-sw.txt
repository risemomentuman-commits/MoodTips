// web/firebase-messaging-sw.js
// Service Worker pour recevoir les notifications même quand l'app est fermée

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// ⚠️ REMPLACE PAR TA CONFIG FIREBASE
const firebaseConfig = {
  apiKey: "AIzaSyCSdZQtz9blpwpXx54EQ4mHudmcGs66QjA",
  authDomain: "moodtips-f2f0b.firebaseapp.com",
  projectId: "moodtips-f2f0b",
  storageBucket: "moodtips-f2f0b.firebasestorage.app",
  messagingSenderId: "988485491350",
  appId: "1:988485491350:web:27d494da0d1f32553480b7",
  measurementId: "G-Y1QG0N5B52"
};

// Initialiser Firebase
firebase.initializeApp(firebaseConfig);

// Récupérer le service de messaging
const messaging = firebase.messaging();

// Gérer les notifications en arrière-plan (app fermée)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Message reçu en arrière-plan:', payload);
  
  const notificationTitle = payload.notification?.title || 'MoodTips 💙';
  const notificationOptions = {
    body: payload.notification?.body || 'Comment te sens-tu maintenant ?',
    icon: '/icons/Icon-192.png', // ✅ TON LOGO
    badge: '/icons/Icon-192.png', // ✅ TON LOGO (version badge)
    tag: 'moodtips-reminder',
    requireInteraction: false, // Ne force pas l'interaction
    vibrate: [200, 100, 200], // Vibration douce
    data: {
      url: payload.data?.url || '/',
      click_action: payload.data?.click_action || 'https://risemomentuman-commits.github.io/MoodTips/',
    },
  };

  // Afficher la notification
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Gérer le click sur la notification
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification cliquée');
  
  event.notification.close();
  
  const urlToOpen = event.notification.data?.click_action || '/';
  
  // Ouvrir l'app ou focus si déjà ouverte
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Chercher si l'app est déjà ouverte
        for (let i = 0; i < clientList.length; i++) {
          const client = clientList[i];
          if (client.url.includes('MoodTips') && 'focus' in client) {
            return client.focus();
          }
        }
        // Sinon, ouvrir une nouvelle fenêtre
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});