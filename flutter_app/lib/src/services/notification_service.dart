import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
    if (kIsWeb) return;
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
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
  }

  static Future<void> clearToken(String uid) async {
    if (kIsWeb) return;
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

  static const int _hospitalNotifId = 100;
  static const int _jailNotifId = 101;
  static const int _energyNotifId = 102;
  static bool _tzInitialized = false;

  static void _ensureTz() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }

  /// Uygulama arka plana geçtiğinde OS düzeyinde zamanlanmış bildirimler kur.
  /// Uygulama tamamen kapalı olsa bile bunlar çalışır.
  static Future<void> scheduleGameNotifications({
    required int hospitalUntilEpoch,
    required int jailUntilEpoch,
    required int currentEnergy,
    required int maxEnergy,
    required int energyRegenPerMin,
  }) async {
    if (kIsWeb) return;
    _ensureTz();
    await _localNotif.cancel(_hospitalNotifId);
    await _localNotif.cancel(_jailNotifId);
    await _localNotif.cancel(_energyNotifId);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (hospitalUntilEpoch > now + 30) {
      await _scheduleAt(
        id: _hospitalNotifId,
        epoch: hospitalUntilEpoch,
        title: '🏥 Hastaneden çıktın!',
        body: 'Yaralarını sardın, savaşmaya hazırsın.',
      );
    }

    if (jailUntilEpoch > now + 30) {
      await _scheduleAt(
        id: _jailNotifId,
        epoch: jailUntilEpoch,
        title: '⛓️ Serbest kaldın!',
        body: 'Cezaevinden çıktın. Sokaklar seni bekliyor.',
      );
    }

    if (currentEnergy < maxEnergy && energyRegenPerMin > 0) {
      final missingEnergy = maxEnergy - currentEnergy;
      final secondsToFull = (missingEnergy / energyRegenPerMin * 60).ceil();
      final fullEpoch = now + secondsToFull;
      if (secondsToFull > 60) {
        await _scheduleAt(
          id: _energyNotifId,
          epoch: fullEpoch,
          title: '⚡ Enerji doldu!',
          body: 'Saldırıya hazırsın. Rakiplerini ez!',
        );
      }
    }
  }

  static Future<void> cancelGameNotifications() async {
    if (kIsWeb) return;
    await _localNotif.cancel(_hospitalNotifId);
    await _localNotif.cancel(_jailNotifId);
    await _localNotif.cancel(_energyNotifId);
  }

  static Future<void> _scheduleAt({
    required int id,
    required int epoch,
    required String title,
    required String body,
  }) async {
    try {
      final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        epoch * 1000,
      );
      await _localNotif.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
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
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[Notification] scheduleAt failed: $e');
    }
  }
}
