import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus { unknown, needsLogin, authenticated }

/// Menyimpan status login & profil user yang sedang aktif.
/// Sepenuhnya offline: sesi disimpan di HP (lihat ApiService), tidak ada
/// lagi konsep "alamat server" karena tidak ada server yang dipanggil.
class AuthProvider extends ChangeNotifier {
  final _api = ApiService.instance;

  AuthStatus status = AuthStatus.unknown;
  Me? me;
  String? errorMessage;

  Future<void> bootstrap() async {
    await _api.load();
    if (!_api.hasToken) {
      status = AuthStatus.needsLogin;
      notifyListeners();
      return;
    }
    // Validasi sesi tersimpan (mirip pemanggilan action "me")
    try {
      final data = await _api.call('me');
      me = Me.fromJson(Map<String, dynamic>.from(data));
      status = AuthStatus.authenticated;
      _updateFcmToken();
    } catch (_) {
      await _api.setToken(null);
      status = AuthStatus.needsLogin;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    errorMessage = null;
    try {
      final data = await _api.call('auth.login', {'email': email, 'password': password});
      final map = Map<String, dynamic>.from(data);
      await _api.setToken(map['token']);
      me = Me.fromJson(Map<String, dynamic>.from(map['me']));
      status = AuthStatus.authenticated;
      notifyListeners();
      
      _updateFcmToken();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.setToken(null);
    me = null;
    status = AuthStatus.needsLogin;
    notifyListeners();
  }

  Future<void> _updateFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.call('user.updateFCM', {'fcm_token': token});
        if (me != null) {
          try {
            await Supabase.instance.client
                .from('users')
                .update({
                  'fcm_token': token,
                  'last_modified': DateTime.now().toUtc().toIso8601String(),
                })
                .ilike('email', me!.email);
            debugPrint('[FCM] Token updated to Supabase: $token');
          } catch (e) {
            debugPrint('[FCM] Failed direct Supabase token update: $e');
          }
        }
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _api.call('user.updateFCM', {'fcm_token': newToken});
        if (me != null) {
          try {
            await Supabase.instance.client
                .from('users')
                .update({
                  'fcm_token': newToken,
                  'last_modified': DateTime.now().toUtc().toIso8601String(),
                })
                .ilike('email', me!.email);
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('FCM Error: $e');
    }
  }
}
