import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'kasirku_alerts',
    'KasirKu Alerts',
    description: 'Notifikasi aktivitas dan transaksi kasir',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Inisialisasi plugin notifikasi lokal & pembuatan notification channel
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(settings: initSettings);

      // Buat notification channel untuk Android 8.0+ (API 26+)
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Request permission untuk Android 13+ (API 33+)
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _isInitialized = true;
      debugPrint('[NotificationService] Local notifications initialized with channel kasirku_alerts');
    } catch (e) {
      debugPrint('[NotificationService] Failed to init local notifications: $e');
    }
  }

  /// Menampilkan popup notifikasi (heads-up banner & sound di jendela HP)
  Future<void> showNotification(String title, String body, {int id = 0}) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );
      final details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('[NotificationService] Shown local popup notification: $title - $body');
    } catch (e) {
      debugPrint('[NotificationService] Failed to show local notification: $e');
    }
  }

  /// Menampilkan notifikasi dari pesan Remote FCM
  Future<void> showNotificationFromRemote(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'KasirKu: Aktivitas Baru';
    final body = message.notification?.body ?? message.data['body'] ?? 'Ada aktivitas baru di kasir';
    final id = message.messageId.hashCode;
    await showNotification(title, body, id: id);
  }

  static const String _projectId = 'kasirku-app-b27c6';

  // Kredensial Service Account yang di-encode base64
  static const String _serviceAccountBase64 = 
      'eyJ0eXBlIjoic2VydmljZV9hY2NvdW50IiwicHJvamVjdF9pZCI6Imthc2lya3UtYXBwLWIyN2M2IiwicHJpdmF0ZV9rZXlfaWQiOiJiNzA2MzgxYjAxNDVhYzhkOTg3MDEwYzU3ZjczZWZlNjEzYTk2M2Y1IiwicHJpdmF0ZV9rZXkiOiItLS0tLUJFR0lOIFBSSVZBVEUgS0VZLS0tLS1cbk1JSUV2QUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktZd2dnU2lBZ0VBQW9JQkFRQ29weEZ0QitQUTVBcFAKaFJSRDRoVVJ3dk5DaEluZXV1NW9PckZBQ0UvajB3QzlRQkRJZjhBSmczL2I5eHZ3SXd5QnREdzE4YlltNVFwTDEKZDdVKzFjeUozTndtNzJBR1JzL0RSeWNkQ2U3Qk5Qd3dna3VIekVna3hnWXR4c2h6VFhnN0pKT0d5OXJuVUtKazIKMmg0YUI3T2lkck44ZU1nMXZ6UDVjUWZaUWFLM1lrQjc5ME5PYW5VZDNZNW84RFVDM0MyY1RSelFHMW02djI2ZgpmVkh4cG1HWE1ncVdaaW9WL3o5Y0VrRVFRSXBNWENtTTErVXdjMFVKZFBUTWRaL1lwenNTaUx2MHpVSERBQXBnClJicDtyOXN1dzhRN2tEamgrN3hIdWtzb29LU1M1eFFLdmtnMkprbVhqNGRySitYNVZ1QXJiU2pLMGFrVWJnaWIKdzBFcklPQ2hBZ01CQUFFQ2dnRUFHM0ZUL0pIVUdDR0RLLzFUbXU3RHp1Z1IvVHRqMWtKZ2h4S3kwaU85MXRXTwozVTVSZWJEc01pYy9ZWHdHYUFLWVBDYSs0d2hQNkwxVWZHekdLVHRRMVA0RE5MS3V4VmF3Wis0a0J5MmVsQUd6Cko1R01DTVRNMkc4QWdtSmVLNlRuYzNnNEtTN3lwOEVQSzZueVNvb0UyT0xId2ZGRllybUNFNFk0NGpreTZQTG8KSCtZc1VnZ2VCUTFYaXE3YlBRK0o3ZGt4UXQxR3NhaVlPek80ZGp4bDlQT0xyNk9QeWTRY0F6L290MFQyeUR4bApMa0NvVEU5VExxa1FUa25qRXlxTWhCTDYvampiSDFaYTJ5ZDdOU1dNTnZQUW9jYWgwbGd4elRNaWN5U01WNnVhClVTVW1oOGc3VW1YRWFlWUpldDRTRDhqU3pqVkswdFNpZ1ZMK1dOaWdCSVFLRmdRRGIvSVQzNERxbTcyWXNGUEY5CjdheGlnd1A3NEhSYURTTXBucnRuS05MeFgvM3ZCYmdOdEd3RXBZbHp1N0VYcHM5MEZFZG5TdzFKVjVVN2wrNzgKYXhKejVyZi9jZXpMaFNmb2lremZhNmtRa0NIeHhIRiswQVBLNnN2d201dTBkTEpySWRZNEZJb21DUkxQVk5uCjhKRVdsOFVRNFY4TzRjYXlodXRxYzFVNUt3S0JnUURFUXk4cktWTzNsbm5GTzNPSHZyTExXb0hOMzdTVEQxKzYKb1VVZkVoSlVWakRUTHMDeUFFTFFHUFlCNTVRb0ZjRWFTWklRSHcvRURKeFg4R09uSmMvdnVmRm9MR3c5cEkteQo4SnhUOUJheTQ4VEk2N1g1WUM3RmZmVFRNYUhOWHVER3Z2OUZ1VmdFRDdpWVlWM1BzNWdJUkdYR1VKUTUwN01ECjhxa1ptdGJQWXdLQmdIS3ZKTXJzOU9iT2E1K1RrNG9vK09uaGM0cjU3eUNtTkE3MHVlbjJzREVUekMwOUkwQQpnRWV6M1FLZTJPYVFycGxEQ1M0aWJGek44aGhIMk9sekVIMm56RWk1cGM4OExlQUhLYWhZUWgxR1pzdnpsNm1GCkhkeTZzaFlGOFBpSkhyRFE1d2FvZmdPYURXSEVLTlZKRHZxT1NNaFNGSjJORDVZZ2pGNUVuaXRkQW9HQVl5NDYKWWUwUEtrTjl3WWZncDBrN1ZZNjJEanFBMEF2bzhrS0hSck1Vakt4S1hyVi9pQlpyMDFhb0grUVN4eG5yTlhvOAorbU5YMjBvUFhXK09GWHhTNURwOGQwVDlGL2piREY3Ri8zdzBPNUx6QW96cURBOHZEbDFWcXVhVld6bktXNTJuCklzdm1DZ0cwejl1MEUwWDBhRkhIMHZaNWxqU0hTL3l5cW1WMm5VTUNnWUF2WlJRSEJQWTh6OUZvUkJJOFNpQWMSM200L1Y2OVJiaDVMYlh1cDllTW8ydzdpbFdiU2xVczV4dTNWU1I4eE5xTThkZXJpRDNhSC8yaDR2cm00YWVFRgp0UGRVVC9sTzZzZGpYc1J6ZlFtTDhzUkc1S2IwTWVENnNVc3ZZQWFoQk03VmZiVCs5aG00RWxNMGlZdm1kTXd3CjB4ZG10ZkVHeFhldEV6K0szKzFxeVE9PQotLS0tLUVORCBQUklWQVRFIEtFWS0tLS0tXbiIsImNsaWVudF9lbWFpbCI6ImZpcmViYXNlLWFkbWluc2RrLWZic3ZjQGthc2lya3UtYXBwLWIyN2M2LmlhbS5nc2VydmljZWFjY291bnQuY29tIiwiY2xpZW50X2lkIjoiMTA1NDA4MzMwOTQxMzMyODYzMDI3IiwiYXV0aF91cmkiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20vby9vYXV0aDIvYXV0aCIsInRva2VuX3VyaSI6Imh0dHBzOi8vb2F1dGgyLmdvb2dsZWFwaXMuY29tL3Rva2VuIiwiYXV0aF9wcm92aWRlcl94NTA5X2NlcnRfdXJsIjoiaHR0cHM6Ly93d3cuZ29vZ2xlYXBpcy5jb20vb2F1dGgyL3YxL2NlcnRzIiwiY2xpZW50X3g1MDlfY2VydF91cmwiOiJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9yb2JvdC92MS9tZXRhZGF0YS94NTA5L2ZpcmViYXNlLWFkbWluc2RrLWZic3ZjJTQwa2FzaXJrdS1hcHAtYjI3YzYuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJ1bml2ZXJzZV9kb21haW4iOiJnb29nbGVhcGlzLmNvbSJ9';

  Future<String?> _getAccessToken() async {
    try {
      final jsonString = utf8.decode(base64.decode(_serviceAccountBase64));
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);
      final token = authClient.credentials.accessToken.data;
      authClient.close();
      return token;
    } catch (e) {
      debugPrint('Gagal mendapatkan access token: $e');
      return null;
    }
  }

  /// Membaca token Admin langsung dari Supabase (dan fallback ke DB lokal jika offline)
  Future<List<String>> _getAdminTokens(Database db) async {
    final tokens = <String>{};
    // 1. Coba ambil langsung dari Supabase agar selalu realtime & akurat lintas perangkat
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('fcm_token')
          .ilike('role', 'admin')
          .neq('fcm_token', '');
      for (final r in res) {
        final t = r['fcm_token']?.toString().trim() ?? '';
        if (t.isNotEmpty) tokens.add(t);
      }
      debugPrint('[NotificationService] Found ${tokens.length} admin token(s) from Supabase');
    } catch (e) {
      debugPrint('[NotificationService] Supabase token fetch fallback to local: $e');
    }

    // 2. Jika offline / belum dapat, ambil dari DB lokal
    if (tokens.isEmpty) {
      try {
        final rows = await db.query(
          'users',
          columns: ['fcm_token'],
          where: "LOWER(role) = ? AND fcm_token != '' AND fcm_token IS NOT NULL",
          whereArgs: ['admin'],
        );
        for (final r in rows) {
          final t = r['fcm_token']?.toString().trim() ?? '';
          if (t.isNotEmpty) tokens.add(t);
        }
        debugPrint('[NotificationService] Found ${tokens.length} admin token(s) from Local DB');
      } catch (e) {
        debugPrint('Error fetch local admin tokens: $e');
      }
    }
    return tokens.toList();
  }

  /// Fungsi utama yang dipanggil setelah insertAuditLog
  Future<void> notifyAdmins(Database db, String userName, String action, String entity, String details) async {
    try {
      final adminTokens = await _getAdminTokens(db);
      if (adminTokens.isEmpty) {
        debugPrint('[NotificationService] No active admin FCM token found.');
        return;
      }

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('[NotificationService] Could not obtain OAuth2 access token.');
        return;
      }

      const title = "KasirKu: Aktivitas Baru";
      final body = "$userName telah $action $entity. ($details)";

      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

      for (String token in adminTokens) {
        final payload = {
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                'sound': 'default',
                'default_sound': true,
                'default_vibrate_timings': true,
                'channel_id': 'kasirku_alerts',
                'notification_priority': 'PRIORITY_MAX',
              }
            },
            'data': {
              'type': 'monitoring_alert',
              'title': title,
              'body': body,
              'user_name': userName,
              'action': action,
              'entity': entity,
              'details': details,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            }
          }
        };

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          debugPrint('FCM Error for token $token: ${response.body}');
        } else {
          debugPrint('FCM Success sent to $token: $body');
        }
      }
    } catch (e) {
      debugPrint('Error notifyAdmins: $e');
    }
  }
}
