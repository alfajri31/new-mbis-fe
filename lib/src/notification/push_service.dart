import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../auth/auth_session.dart';
import '../network/api_client.dart';
import '../../presentation/screens/notifikasi_screen.dart';
import 'device_api.dart';

/// Background isolate handler. Must be a top-level / static function annotated with
/// `@pragma('vm:entry-point')`. For "notification" messages Android shows the system
/// tray entry automatically, so there's nothing to do here; tap routing happens via
/// onMessageOpenedApp when the user opens the app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

const String _androidChannelId = 'mbis_default_channel';
const String _androidChannelName = 'Notifikasi M-BIS';

/// Owns the FCM lifecycle on the client: permission, the local-notification channel
/// for foreground display, token registration with the backend, and deep-link routing
/// when a notification is tapped. Everything is wrapped in try/catch so a missing or
/// placeholder Firebase config degrades to "push disabled" without crashing the app.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  AuthSession? Function()? _sessionProvider;
  bool _initialized = false;
  String? _registeredToken;

  String get _platform {
    if (kIsWeb) return 'WEB';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
  }

  /// One-time setup of permission + listeners. [sessionProvider] yields the current
  /// auth session (used to attach the bearer token on (re)registration). Safe to call
  /// more than once. No-op on web (push there needs separate VAPID config).
  Future<void> init(AuthSession? Function() sessionProvider) async {
    _sessionProvider = sessionProvider;
    if (_initialized || kIsWeb) return;
    try {
      await _setupLocalNotifications();
      await FirebaseMessaging.instance.requestPermission();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _route(m.data));
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

      // App opened cold from a notification tap.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Defer until the first frame so the navigator/router exists.
        WidgetsBinding.instance.addPostFrameCallback((_) => _route(initial.data));
      }
      _initialized = true;
    } catch (e) {
      debugPrint('PushService disabled (Firebase not configured): $e');
    }
  }

  /// Registers this device's token for the current session. Call on login and on
  /// session restore (after [init]).
  Future<void> registerForCurrentSession() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('FCM token registration skipped: $e');
    }
  }

  /// Unregisters this device for [session] (called on logout, while the session is
  /// still valid) and drops the local token so a later login fetches a fresh one.
  Future<void> unregisterForSession(AuthSession session) async {
    if (kIsWeb) return;
    final token = _registeredToken;
    try {
      if (token != null) {
        await DeviceApi(ApiClient(session: session)).unregister(token);
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM unregister skipped: $e');
    }
    _registeredToken = null;
  }

  Future<void> _onTokenRefresh(String token) async {
    try {
      await _registerToken(token);
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    final session = _sessionProvider?.call();
    if (session == null) return; // not signed in; will register on next login
    await DeviceApi(ApiClient(session: session)).registerToken(token, platform: _platform);
    _registeredToken = token;
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS: don't prompt here — FirebaseMessaging.requestPermission() already asks for
    // the system push permission, so we'd otherwise show two dialogs.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          _route(_decode(payload));
        }
      },
    );
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Pengingat kunjungan, pengumuman, dan notifikasi lain.',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Foreground messages don't surface a tray notification automatically, so render
  /// one via flutter_local_notifications. The data payload rides along for tap routing.
  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        // iOS suppresses FCM "notification" payloads while foregrounded, so we render
        // one locally (same as Android). These flags let it surface in the foreground.
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Routes a tapped notification to the relevant screen using the global navigator.
  void _route(Map<String, dynamic> data) {
    final context = MbisApp.navigatorKey.currentContext;
    if (context == null) return;
    final type = data['type']?.toString();
    final pipelineId = data['pipelineId']?.toString();
    // Tipe yang menunjuk ke sebuah pipeline lewat data['pipelineId'] (mis. reminder
    // visit/tender, referral, WON/DECLINE, jadwal ditugaskan). Untuk tender reminder
    // refId adalah id PROSES, bukan pipeline, jadi kita pakai pipelineId dari data.
    const pipelineTypes = {
      'VISIT_REMINDER',
      'TENDER_REMINDER',
      'REFERRAL',
      'PIPELINE_WON',
      'PIPELINE_STAGNANT',
      'SCHEDULE_ASSIGNED',
    };
    if (pipelineTypes.contains(type) && pipelineId != null && pipelineId.isNotEmpty) {
      GoRouter.of(context).go('/dashboard/pipeline/$pipelineId');
      return;
    }
    // Agent onboarding / license notifications deep-link to the agent detail.
    final refType = data['refType']?.toString();
    final refId = data['refId']?.toString();
    if (refType == 'AGENT' && refId != null && refId.isNotEmpty) {
      GoRouter.of(context).go('/agent-detail/$refId');
      return;
    }
    // Komisi dirilis/dibayar → tab komisi agen (samakan dengan tap di inbox).
    if (refType == 'COMMISSION') {
      GoRouter.of(context).go('/agent/komisi');
      return;
    }
    // Announcements (and anything else) open the inbox.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
    );
  }

  Map<String, dynamic> _decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }
}
