import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cihaz.dart';

class CihazServisi {
  static final CihazServisi _instance = CihazServisi._internal();
  factory CihazServisi() => _instance;
  CihazServisi._internal();

  // Firestore referansı
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cihazlarCollection = 'cihazlar';

  List<Cihaz> _cihazlar = [];
  bool _verilerYuklendi = false;
  bool _ilkKurulumYapildi = false;

  List<Cihaz> get cihazlar => List.unmodifiable(_cihazlar);

  /// Uygulama başlangıcında verileri yükle
  /// Önce Firebase'den veri çeker, yoksa JSON'dan ilk kurulum yapar
  Future<void> init() async {
    if (_verilerYuklendi) return;
    
    try {
      // Önce Firebase'den verileri yükle
      await _firestoreDanYukle();
      
      // Firebase'de veri yoksa JSON'dan ilk kurulum yap
      if (_cihazlar.isEmpty && !_ilkKurulumYapildi) {
        print('📋 Firebase boş, JSON\'dan ilk kurulum yapılıyor...');
        await _jsonDanIlkKurulum();
        _ilkKurulumYapildi = true;
      }
      
      _verilerYuklendi = true;
      print('✅ Cihaz verileri yüklendi: ${_cihazlar.length} cihaz');
    } catch (e) {
      print('❌ Veri yükleme hatası: $e');
      // Hata durumunda sadece JSON'dan yükle (çevrimdışı mod)
      await _jsonDanYukle();
      _verilerYuklendi = true;
    }
  }

  /// Firebase Firestore'dan verileri yükle
  Future<void> _firestoreDanYukle() async {
    try {
      final snapshot = await _firestore
          .collection(_cihazlarCollection)
          .orderBy('servoBizNo', descending: true)
          .get();
      
      _cihazlar = snapshot.docs.map((doc) {
        final data = doc.data();
        return Cihaz.fromJson(data);
      }).toList();
      
      print('✅ Firestore\'dan ${_cihazlar.length} cihaz yüklendi');
    } catch (e) {
      print('⚠️ Firestore yükleme hatası: $e');
      rethrow;
    }
  }

  /// JSON dosyasından ilk kurulum - verileri Firebase'e de kaydet
  Future<void> _jsonDanIlkKurulum() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      // JSON yapısı: {"ETİKETLENDİ": [...]} şeklinde
      List<dynamic> jsonList = [];
      if (jsonData.containsKey('ETİKETLENDİ')) {
        jsonList = jsonData['ETİKETLENDİ'] as List;
      } else {
        // Diğer olası anahtarları kontrol et
        for (final entry in jsonData.entries) {
          if (entry.value is List) {
            jsonList = entry.value as List;
            break;
          }
        }
      }
      
      if (jsonList.isEmpty) {
        print('⚠️ JSON dosyasında veri bulunamadı');
        return;
      }
      
      // Batch write için
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      const int batchLimit = 400; // Firestore batch limiti 500
      
      for (final json in jsonList) {
        final cihaz = _jsonKayitDonustur(json as Map<String, dynamic>);
        if (cihaz != null) {
          _cihazlar.add(cihaz);
          
          // Firebase'e kaydet
          final docRef = _firestore.collection(_cihazlarCollection).doc(cihaz.servoBizNo);
          batch.set(docRef, cihaz.toJson());
          batchCount++;
          
          // Batch limitine ulaşıldıysa commit et
          if (batchCount >= batchLimit) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
            print('📊 İlerleme: ${_cihazlar.length} cihaz Firebase\'e kaydedildi');
          }
        }
      }
      
      // Kalan verileri commit et
      if (batchCount > 0) {
        await batch.commit();
      }
      
      print('✅ JSON\'dan ${_cihazlar.length} cihaz Firebase\'e yüklendi');
    } catch (e) {
      print('❌ JSON ilk kurulum hatası: $e');
    }
  }

  /// JSON dosyasından sadece local yükleme (çevrimdışı mod)
  Future<void> _jsonDanYukle() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      List<dynamic> jsonList = [];
      if (jsonData.containsKey('ETİKETLENDİ')) {
        jsonList = jsonData['ETİKETLENDİ'] as List;
      } else {
        for (final entry in jsonData.entries) {
          if (entry.value is List) {
            jsonList = entry.value as List;
            break;
          }
        }
      }
      
      _cihazlar = jsonList
          .map((json) => _jsonKayitDonustur(json as Map<String, dynamic>))
          .where((c) => c != null)
          .cast<Cihaz>()
          .toList();
      
      print('✅ JSON\'dan ${_cihazlar.length} cihaz yüklendi (çevrimdışı)');
    } catch (e) {
      print('❌ JSON yükleme hatası: $e');
      _cihazlar = [];
    }
  }

  /// JSON kaydını Cihaz modeline dönüştür
  Cihaz? _jsonKayitDonustur(Map<String, dynamic> json) {
    // Alan isimlerini esnek şekilde bul
    String? _al(List<String> anahtarlar) {
      for (final anahtar in anahtarlar) {
        final value = json[anahtar];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return null;
    }
    
    // ServoBiz No (zorunlu)
    final servoBizNo = _al(['Cihaza Verilen No', 'servoBizNo', 'SERVO BİZ NO']);
    if (servoBizNo == null || servoBizNo.isEmpty) return null;
    
    // Tarih
    final tarihStr = _al(['Tarih', 'tarih', 'TARİH']);
    final tarih = _formatTarih(tarihStr);
    
    // Seri No
    final seriNo = _al(['Cihaz Seri No', 'seriNo', 'CİHAZ SERİ NO']) ?? '';
    
    // Marka Model / Ürün
    final markaModel = _al(['Ürün', 'markaModel', 'ÜRÜN', 'CİHAZ ADI']) ?? '';
    
    // Durum - "Cihaz Durumu" veya "LOBİDE BEKLEMEDE" alanlarından al
    String durumStr = _al(['Cihaz Durumu', 'durum', 'CİHAZ DURUMU']) ?? '';
    if (durumStr.isEmpty || durumStr == 'ÇIKIŞI YAPILDI') {
      // LOBİDE BEKLEMEDE alanında gerçek durum olabilir
      final lobideDurum = _al(['LOBİDE BEKLEMEDE']);
      if (lobideDurum != null && lobideDurum.isNotEmpty) {
        durumStr = lobideDurum;
      }
    }
    final durum = _formatDurum(durumStr.isNotEmpty ? durumStr : 'Lobide');
    
    // Firma
    final firmaIsmi = _al(['Firma', 'firmaIsmi', 'MÜŞTERİ']) ?? '';
    
    // Notlar / Yapılan İşlem
    final notlar = _al(['Yapılan İşlem', 'notlar', 'YAPILAN İŞLEM']);
    
    return Cihaz(
      servoBizNo: servoBizNo,
      tarih: tarih,
      seriNo: seriNo,
      markaModel: markaModel,
      durum: durum,
      firmaIsmi: firmaIsmi,
      notlar: notlar,
      kaydedenKullaniciAdi: 'sistem',
      sonGuncelleyen: 'sistem',
      sonDurumDegisiklikTarihi: DateTime.now(),
    );
  }

  /// Cihaz ekle - Firebase'e de kaydet
  Future<void> cihazEkle(Cihaz cihaz) async {
    try {
      // Firebase'e kaydet
      await _firestore
          .collection(_cihazlarCollection)
          .doc(cihaz.servoBizNo)
          .set(cihaz.toJson());
      
      // Yerel listeye ekle
      final existingIndex = _cihazlar.indexWhere((c) => c.servoBizNo == cihaz.servoBizNo);
      if (existingIndex >= 0) {
        _cihazlar[existingIndex] = cihaz;
      } else {
        _cihazlar.add(cihaz);
      }
      
      print('✅ Cihaz kaydedildi (Firebase + Local): ${cihaz.servoBizNo}');
    } catch (e) {
      print('❌ Cihaz kaydetme hatası: $e');
      // Hata durumunda sadece local'e ekle
      _cihazlar.add(cihaz);
    }
  }

  /// ServoBiz No ile cihaz bul
  Cihaz? cihazBul(String servoBizNo) {
    try {
      return _cihazlar.firstWhere((c) => c.servoBizNo == servoBizNo);
    } catch (e) {
      return null;
    }
  }

  /// Durum güncelle - Firebase'e de kaydet
  Future<bool> durumGuncelle(String servoBizNo, String yeniDurum, {String? notlar}) async {
    try {
      final index = _cihazlar.indexWhere((c) => c.servoBizNo == servoBizNo);
      if (index == -1) return false;
      
      final eskiCihaz = _cihazlar[index];
      final guncelCihaz = eskiCihaz.copyWith(
        durum: yeniDurum,
        notlar: notlar ?? eskiCihaz.notlar,
        sonGuncelleyen: eskiCihaz.sonGuncelleyen,
        sonDurumDegisiklikTarihi: DateTime.now(),
      );
      
      // Firebase'e kaydet
      await _firestore
          .collection(_cihazlarCollection)
          .doc(servoBizNo)
          .update(guncelCihaz.toJson());
      
      // Yerel listeyi güncelle
      _cihazlar[index] = guncelCihaz;
      print('✅ Durum güncellendi (Firebase + Local): $servoBizNo -> $yeniDurum');
      return true;
    } catch (e) {
      print('❌ Durum güncelleme hatası: $e');
      return false;
    }
  }

  /// Tüm cihazları sil (admin için)
  Future<void> tumCihazlariSil() async {
    try {
      // Firebase'den sil (batch ile)
      final snapshot = await _firestore.collection(_cihazlarCollection).get();
      WriteBatch batch = _firestore.batch();
      int count = 0;
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
      
      // Yerel listeyi temizle
      _cihazlar.clear();
      _ilkKurulumYapildi = false;
      print('🗑️ Tüm cihazlar silindi (Firebase + Local)');
    } catch (e) {
      print('❌ Silme hatası: $e');
      _cihazlar.clear();
    }
  }

  /// Verileri yenile (Firebase'den tekrar çek)
  Future<void> yenile() async {
    _verilerYuklendi = false;
    await init();
  }

  /// Tarih formatını düzenle
  String _formatTarih(String? tarihInput) {
    if (tarihInput == null || tarihInput.isEmpty) return _getBugunTarihi();
    
    try {
      // M/D/YY formatı (8/22/25)
      if (tarihInput.contains('/')) {
        final parts = tarihInput.split('/');
        if (parts.length == 3) {
          String year = parts[2];
          // 2 haneli yıl ise 2000'li yıllara çevir
          if (year.length == 2) {
            year = '20$year';
          }
          return '${parts[1].padLeft(2, '0')}/${parts[0].padLeft(2, '0')}/$year';
        }
      }
      return tarihInput;
    } catch (e) {
      return _getBugunTarihi();
    }
  }

  /// Bugünün tarihini GG/AA/YYYY formatında döndür
  String _getBugunTarihi() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  /// Durum formatını düzenle
  String _formatDurum(String durum) {
    final durumUpper = durum.toUpperCase().trim();
    
    if (durumUpper.contains('ÇIKIŞ') || durumUpper.contains('CIKIS')) {
      return 'Çıkış Yapıldı';
    } else if (durumUpper.contains('ATÖLYE') || durumUpper.contains('ATOLYE') || durumUpper.contains('SEVK')) {
      return 'Atolye Sevk';
    } else if (durumUpper.contains('TEST')) {
      return 'Test Ünitesi Sevk';
    } else if (durumUpper.contains('TESLİM') || durumUpper.contains('TESLIM') || durumUpper.contains('HAZIR')) {
      return 'Teslime Hazır';
    } else if (durumUpper.contains('NUMARA')) {
      return 'Lobide';
    } else if (durumUpper.contains('LOBİ') || durumUpper.contains('LOBI') || durumUpper.contains('BEKLE')) {
      return 'Lobide';
    }
    
    return 'Lobide';
  }
}