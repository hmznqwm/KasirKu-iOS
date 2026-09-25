import 'package:flutter/material.dart';

/// EventProvider digunakan sebagai event bus sederhana untuk memicu
/// auto-refresh data di seluruh aplikasi saat ada perubahan data.
class EventProvider extends ChangeNotifier {
  int _produkVersion = 0;
  int _transaksiVersion = 0;
  int _userVersion = 0;

  int get produkVersion => _produkVersion;
  int get transaksiVersion => _transaksiVersion;
  int get userVersion => _userVersion;

  void refreshProduk() {
    _produkVersion++;
    notifyListeners();
  }

  void refreshTransaksi() {
    _transaksiVersion++;
    notifyListeners();
  }
  
  void refreshUser() {
    _userVersion++;
    notifyListeners();
  }
}
