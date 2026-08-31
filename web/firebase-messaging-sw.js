// This file must live at web/firebase-messaging-sw.js in your Flutter project
// (same folder as web/index.html). It's picked up automatically by the
// Firebase Messaging web SDK — no code elsewhere needs to reference it.

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Fill these in from Firebase Console > Project Settings > General > Your apps
// (Web app) — or copy them straight out of lib/firebase_options.dart, the
// values under the "web" FirebaseOptions block match exactly.
firebase.initializeApp({
  apiKey: "AIzaSyA_j7ykUfvGEjmRO2aWd40YJDlNAb1r0Vo",
  authDomain: "true-barber-58d7c.firebaseapp.com",
  projectId: "true-barber-58d7c",
  storageBucket: "true-barber-58d7c.firebasestorage.app",
  messagingSenderId: "781190414818",
  appId: "1:781190414818:web:f54d7880ab005d5c6b39bb",
});

const messaging = firebase.messaging();