// ...existing code...
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/cihaz.dart';
import 'cihaz_servisi.dart';

class VeriYuklemeServisi {
  /// JSON dosyasındaki cihazları uyg. modeline uygun şekilde ekler. Hatalı veya eksik kayıtları atlar.
  static Future<int> jsonVerileriniYukle() async {
    int yuklenenSayi = 0;
    int zatenVarSayi = 0;
    int hataSayi = 0;
    try {
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final List<dynamic> cihazListesi = _cihazListesiAl(jsonMap);

      final servisi = CihazServisi();
      for (int i = 0; i < cihazListesi.length; i++) {
        final cihazJson = cihazListesi[i];
        try {
          final cihaz = _cihazModelDonustur(cihazJson);
          if (cihaz == null) {
            hataSayi++;
            continue;
          }
          // Aynı ServoBizNo ile cihaz var mı kontrol et
          final varMi = servisi.cihazBul(cihaz.servoBizNo);
          if (varMi != null) {
            zatenVarSayi++;
            continue; // Zaten kayıtlı
          }
          await servisi.cihazEkle(cihaz);
          yuklenenSayi++;
          if (yuklenenSayi % 10 == 0) {
            print('📊 İlerleme: $yuklenenSayi / ${cihazListesi.length}');
          }
        } catch (e) {
          print('❌ Kayıt işlenirken hata: $e');
          hataSayi++;
        }
      }
      print('✅ Yükleme tamamlandı!');
      print('   📈 Toplam: ${cihazListesi.length}');
      print('   ✅ Yüklenen: $yuklenenSayi');
      print('   ⚠️ Zaten var: $zatenVarSayi');
      print('   ❌ Hatalı: $hataSayi');
      return yuklenenSayi;
    } catch (e) {
      print('❌ Veri yükleme hatası: $e');
      return 0;
    }
  }

  /// JSON'dan cihaz listesi alanını bulur (farklı anahtarlar için esnek)
  static List<dynamic> _cihazListesiAl(Map<String, dynamic> jsonMap) {
    // Sık kullanılan anahtarlar
    final anahtarlar = [
      'ETİKETLENDİ',
      'cihazlar',
      'devices',
    ];
    for (final key in anahtarlar) {
      if (jsonMap.containsKey(key) && jsonMap[key] is List) {
        return jsonMap[key] as List;
      }
    }
    // İlk bulunan List tipindeki alanı döndür
    for (final entry in jsonMap.entries) {
      if (entry.value is List) return entry.value as List;
    }
    return [];
  }

  /// JSON cihaz kaydını Cihaz modeline dönüştürür. Eksik zorunlu alanlarda null döner.
  static Cihaz? _cihazModelDonustur(Map<String, dynamic> cihazJson) {
    // Alan isimlerini normalize et
    String? _al(List<String> anahtarlar) {
      for (final anahtar in anahtarlar) {
        final entry = cihazJson.entries.firstWhere(
          (e) => e.key.replaceAll(' ', '').toLowerCase() == anahtar.replaceAll(' ', '').toLowerCase(),
          orElse: () => MapEntry('', null),
        );
        if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
          return entry.value.toString();
        }
      }
      return null;
    }

    final String? servoBizNo = _al(['SERVO BİZ NO', 'servoBizNo']);
    if (servoBizNo == null || servoBizNo.isEmpty) return null;

    // Modelde zorunlu alanlar: servoBizNo, tarih, seriNo, markaModel, durum
    final String tarih = _formatTarih(_al(['TARİH', 'tarih']));
    final String seriNo = _al(['CİHAZ SERİ NO', 'seriNo']) ?? '';
    final String markaModel = _al(['CİHAZ ADI', 'markaModel', 'ÜRÜN', 'ürün']) ?? '';
    final String durum = _formatDurum(_al(['CİHAZ DURUMU', 'durum']) ?? 'Lobide');

    return Cihaz(
      servoBizNo: servoBizNo,
      tarih: tarih,
      seriNo: seriNo,
      markaModel: markaModel,
      durum: durum,
      cihazTuru: _al(['CİHAZ TİPİ', 'cihazTuru']),
      yanilanIslem: _al(['YAPILAN İŞLEM', 'yanilanIslem']),
      firmaIsmi: _al(['MÜŞTERİ', 'firmaIsmi', 'firma']),
      notlar: _al(['NOTLAR', 'notlar']),
      kaydedenKullaniciAdi: _al(['KAYDEDEN', 'kaydedenKullaniciAdi']),
      sonGuncelleyen: _al(['SON GÜNCELLEYEN', 'sonGuncelleyen']),
      sonDurumDegisiklikTarihi: DateTime.now(),
      islemRaporlari: [],
    );
  }

  /// Tarih stringini DateTime'a çevirir. Hatalıysa null döner.
  /// Tarih formatını düzenle (çeşitli formatları destekler)
  static String _formatTarih(String? tarihInput) {
    if (tarihInput == null) return _getBugunTarihi();
    String tarihStr = tarihInput.trim();
    if (tarihStr.isEmpty) return _getBugunTarihi();
    try {
      // ISO formatı (2025-08-22T00:00:00)
      if (tarihStr.contains('T')) {
        DateTime dt = DateTime.parse(tarihStr);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
      // Tireli format (2025-08-22)
      if (tarihStr.contains('-') && tarihStr.length == 10) {
        var parts = tarihStr.split('-');
        if (parts.length == 3) {
          return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
        }
      }
      // Noktalı format (22.08.2025)
      if (tarihStr.contains('.')) {
        var parts = tarihStr.split('.');
        if (parts.length == 3) {
          return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[2]}';
        }
      }
      // Slashli format (22/08/2025)
      if (tarihStr.contains('/')) {
        var parts = tarihStr.split('/');
        if (parts.length == 3) {
          return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[2]}';
        }
      }
      return tarihStr;
    } catch (e) {
      return _getBugunTarihi();
    }
  }

  /// Durum formatını düzenle (uygulama formatına çevir)
  static String _formatDurum(String durum) {
    String durumUpper = durum.toUpperCase().trim();
    if (durumUpper.contains('ÇIKIŞ') || durumUpper.contains('CIKIS')) {
      return 'Çıkış Yapıldı';
    } else if (durumUpper.contains('ATÖLYE') || durumUpper.contains('ATOLYE')) {
      return 'Atolye Sevk';
    } else if (durumUpper.contains('TEST')) {
      return 'Test Ünitesi Sevk';
    } else if (durumUpper.contains('TESLİM') || durumUpper.contains('TESLIM') || durumUpper.contains('HAZIR')) {
      return 'Teslime Hazır';
    } else if (durumUpper.contains('LOBİ') || durumUpper.contains('LOBI') || durumUpper.contains('BEKLE')) {
      return 'Lobide';
    }
    return 'Lobide'; // Varsayılan
  }

  /// Bugünün tarihini GG/AA/YYYY formatında döndür
  static String _getBugunTarihi() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
// ...existing code...
// (Tüm fonksiyonlar yukarıda tanımlı)

  /// Tarih formatını düzenle (çeşitli formatları destekler)

}