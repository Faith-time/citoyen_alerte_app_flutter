// lib/core/services/push_notification_service.dart
//
// NOUVEAU FICHIER — service de notifications push, un topic par rôle.
// Aucune gestion de token côté serveur nécessaire : l'abonnement aux
// topics se fait directement depuis le téléphone via le SDK Firebase.

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';

/// Handler de fond — DOIT être une fonction top-level (hors classe),
/// c'est une contrainte de Firebase. Ne fait qu'initialiser Firebase
/// si besoin ; l'affichage de la notif système est géré nativement par
/// Android/iOS quand l'app est fermée ou en arrière-plan.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Rien à faire ici : FCM affiche déjà la notif système en arrière-plan
  // du moment que le payload contient un bloc "notification".
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'alerte_citoyen_default',
    'Alerte Citoyen',
    description: 'Notifications de l\'application Alerte Citoyen',
    importance: Importance.high,
  );

  final List<String> _subscribedTopics = [];

  /// À appeler UNE FOIS au démarrage de l'app (dans main.dart, après
  /// Firebase.initializeApp()).
  Future<void> init() async {
    // Permission (obligatoire iOS, et Android 13+)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Notifications locales — nécessaire pour AFFICHER une notif quand
    // l'app est ouverte au premier plan (FCM ne le fait pas tout seul).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // App ouverte au premier plan → on affiche nous-mêmes la notif locale
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Utilisateur tape sur la notif système (app en arrière-plan)
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleTap(m.data));

    // App lancée DEPUIS une notif (elle était fermée)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // On laisse le temps aux routes/GetX de s'initialiser avant de naviguer.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initialMessage.data));
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;
    _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleTap(data.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {}
  }

  /// Route vers le bon écran selon le "type" envoyé dans le payload data
  /// par le backend. Adapte les noms de routes à ceux de ton app_pages.dart
  /// si besoin (AppRoutes.reportDetails, AppRoutes.chatRoom, etc.).
  void _handleTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'report_status':
        final id = int.tryParse('${data['report_id']}');
        if (id != null) Get.toNamed('/reports/details', arguments: id);
        break;
      case 'new_actuality':
      // Amène le citoyen directement sur l'onglet Actualités du dashboard.
        Get.offAllNamed(Routes.CITIZEN_DASHBOARD, arguments: {'tab': 'actualites'});
        break;
      case 'intervention_assigned':
        Get.offAllNamed(Routes.AGENT_DASHBOARD);
        break;
      case 'authority_new_report':
        Get.offAllNamed(Routes.AUTHORITY_DASHBOARD);
        break;
      case 'chat_message':
        final id = data['thread_id'];
        if (id != null) Get.toNamed('/chat/room', arguments: id);
        break;
      default:
        break;
    }
  }

  // ── Abonnement aux topics selon le rôle ────────────────────────────────

  /// À appeler juste après une connexion réussie (login classique ou
  /// Google), une fois que tu connais le rôle et l'id de l'utilisateur.
  Future<void> subscribeToRoleTopics({
    required String userId,
    required String role, // 'citizen' | 'agent' | 'authority' | 'admin'
    String? authorityId,
  }) async {
    await unsubscribeAll(); // sécurité si un ancien rôle était encore abonné

    final topics = <String>['user_$userId'];
    switch (role) {
      case 'citizen':
        topics.add('role_citizen');
        break;
      case 'agent':
        topics.add('role_agent');
        break;
      case 'authority':
        topics.add('role_authority');
        if (authorityId != null) topics.add('authority_$authorityId');
        break;
      case 'admin':
        topics.add('role_admin');
        break;
    }

    for (final t in topics) {
      await _fcm.subscribeToTopic(t);
    }
    _subscribedTopics
      ..clear()
      ..addAll(topics);
  }

  /// À appeler à la déconnexion.
  Future<void> unsubscribeAll() async {
    for (final t in List<String>.from(_subscribedTopics)) {
      try {
        await _fcm.unsubscribeFromTopic(t);
      } catch (_) {}
    }
    _subscribedTopics.clear();
  }
}