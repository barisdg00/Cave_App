import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/depo.dart';
import '../models/urun_partisi.dart';
import '../models/satis_kaydi.dart';

class DataService {
  static const String _keyDepolar = 'depolar';
  static const String _keyDepoUrunleri = 'depo_urunleri';
  static const String _keySatislar = 'satislar';

  static Future<void> saveAll({
    required List<Depo> depolar,
    required Map<String, List<UrunPartisi>> depoUrunleri,
    required List<SatisKaydi> satislar,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final depolarJson = depolar.map((d) => d.toJson()).toList();
      await prefs.setString(_keyDepolar, jsonEncode(depolarJson));

      // Map'i jsonEncode edilebilir hale getirelim
      final Map<String, dynamic> mappedUrunleri = {};
      depoUrunleri.forEach((key, value) {
        mappedUrunleri[key] = value.map((p) => p.toJson()).toList();
      });
      await prefs.setString(_keyDepoUrunleri, jsonEncode(mappedUrunleri));

      final satislarJson = satislar.map((s) => s.toJson()).toList();
      await prefs.setString(_keySatislar, jsonEncode(satislarJson));
    } catch (e) {
      debugPrint("DataService Save Error: $e");
    }
  }

  static Future<Map<String, dynamic>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    List<Depo> depolar = [];
    Map<String, List<UrunPartisi>> depoUrunleri = {};
    List<SatisKaydi> satislar = [];

    try {
      final depolarStr = prefs.getString(_keyDepolar);
      if (depolarStr != null) {
        final List decoded = jsonDecode(depolarStr);
        depolar = decoded
            .map((d) => Depo.fromJson(d as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint("Load Depolar Error: $e");
    }

    try {
      final urunleriStr = prefs.getString(_keyDepoUrunleri);
      if (urunleriStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(urunleriStr);
        decoded.forEach((key, value) {
          if (value is List) {
            depoUrunleri[key] = value
                .map((p) => UrunPartisi.fromJson(p as Map<String, dynamic>))
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Load Urunler Error: $e");
    }

    try {
      final satislarStr = prefs.getString(_keySatislar);
      if (satislarStr != null) {
        final List decoded = jsonDecode(satislarStr);
        satislar = decoded
            .map((s) => SatisKaydi.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint("Load Satislar Error: $e");
    }

    return {
      'depolar': depolar,
      'depoUrunleri': depoUrunleri,
      'satislar': satislar,
    };
  }
}
