import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService._showLocalNotification(message);
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static final _db = FirebaseFirestore.instance;

  static const _channel = AndroidNotificationChannel(
    'cartelhood_attacks',
    'Saldırı Bildirimleri',
    description: 'Biri sana saldırdığında bildirim alırsın',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> init(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    } catch (e) {
      debugPrint('[Notification] requestPermission failed: $e');
      // Continue anyway — permission may already be granted.
    }

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    try {
      await _refreshToken(uid);
    } catch (e) {
      debugPrint('[Notification] refreshToken failed: $e');
    }

    _messaging.onTokenRefresh.listen((token) => _saveToken(uid, token));

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((msg) {
      _showLocalNotification(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);
  }

  static Future<void> _refreshToken(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);
  }

  static Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
      'platform': Platform.isIOS ? 'ios' : 'android',
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
  }

  static Future<void> clearToken(String uid) async {
    await _messaging.deleteToken();
    await _db.collection('users').doc(uid).update({
      'fcmToken': FieldValue.delete(),
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage msg) async {
    final notif = msg.notification;
    if (notif == null) return;

    await _localNotif.show(
      msg.hashCode,
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
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: msg.data['attackId'],
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    final attackId = response.payload;
    if (attackId != null) {
      navigatorKey.currentState
          ?.pushNamed('/attack_detail', arguments: attackId);
    }
  }

  static void _handleMessageTap(RemoteMessage msg) {
    final attackId = msg.data['attackId'];
    if (attackId != null) {
      navigatorKey.currentState
          ?.pushNamed('/attack_detail', arguments: attackId);
    }
  }

  static final navigatorKey = GlobalKey<NavigatorState>();
}
