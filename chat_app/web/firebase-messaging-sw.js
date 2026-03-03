/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCbC7dp9ibvPfkt5bAoS5WwPdBxw6m7EKA',
  authDomain: 'jhol-jhal-879a1.firebaseapp.com',
  projectId: 'jhol-jhal-879a1',
  storageBucket: 'jhol-jhal-879a1.firebasestorage.app',
  messagingSenderId: '965626965450',
  appId: '1:965626965450:web:e0cb0bc14e74fca39cf333',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'New message';
  const options = {
    body: notification.body || '',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
