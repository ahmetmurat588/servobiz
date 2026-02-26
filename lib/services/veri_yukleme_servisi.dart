import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/cihaz.dart';
import 'cihaz_servisi.dart';

class VeriYuklemeServisi {
  final CihazServisi _cihazServisi = CihazServisi();

  /// JSON dosyasından cihazları yükle
  Future<int> excelVerileriniYukle() async {
    try {
      // Önce Firestore'dan güncel verileri çek (cache'i güncelle)
      await _cihazServisi.yenile();
      
      // JSON dosyasını oku (assets/data.json)
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      int yuklenenSayi = 0;
      int zatenVarSayi = 0;
      int hataSayi = 0;
      
      print('📂 Toplam ${jsonList.length} kayıt bulundu.');
      
      // Her bir JSON nesnesini Cihaz nesnesine çevir
      for (var json in jsonList) {
        try {
          // Gerekli alanları kontrol et
          if (json['servoBizNo'] == null || json['servoBizNo'].toString().isEmpty) {
            print('⚠️ ServoBiz No olmayan kayıt atlandı');
            hataSayi++;
            continue;
          }
          
          // ServoBiz No zaten varsa atla
          if (_cihazServisi.cihazBul(json['servoBizNo'].toString()) != null) {
            print('⚠️ Zaten var: ${json['servoBizNo']}');
            zatenVarSayi++;
            continue;
          }
          
          // Tarihi düzenle (çeşitli formatları dene)
          String tarih = _formatTarih(json['tarih']);
          
          // Durumu düzenle (uygulama formatına çevir)
          String durum = _formatDurum(json['durum'] ?? 'LOBİDE BEKLEMEDE');
          
          // Yeni cihaz oluştur
          final cihaz = Cihaz(
            servoBizNo: json['servoBizNo'].toString().trim(),
            tarih: tarih,
            seriNo: json['seriNo']?.toString().trim() ?? '',
            markaModel: json['markaModel']?.toString().trim() ?? 
                         json['ürün']?.toString().trim() ?? '', // 'Ürün' sütunu da olabilir
            durum: durum,
            firmaIsmi: json['firmaIsmi']?.toString().trim() ?? 
                       json['firma']?.toString().trim() ?? '', // 'Firma' sütunu da olabilir
            notlar: json['notlar']?.toString().trim() ?? 
                    json['yapılan işlem']?.toString().trim() ?? 
                    json['yapılan']?.toString().trim(), // Çeşitli not sütunları
            kaydedenKullaniciAdi: 'admin',
            sonGuncelleyen: 'admin',
            sonDurumDegisiklikTarihi: DateTime.now(),
          );
          
          // Cihaz servisine ekle
          await _cihazServisi.cihazEkle(cihaz);
          yuklenenSayi++;
          
          // Her 10 kayıtta bir ilerleme göster
          if (yuklenenSayi % 10 == 0) {
            print('📊 İlerleme: $yuklenenSayi / ${jsonList.length}');
          }
          
        } catch (e) {
          print('❌ Kayıt işlenirken hata: $e');
          hataSayi++;
        }
      }
      
      print('✅ Yükleme tamamlandı!');
      print('   📈 Toplam: ${jsonList.length}');
      print('   ✅ Yüklenen: $yuklenenSayi');
      print('   ⚠️ Zaten var: $zatenVarSayi');
      print('   ❌ Hatalı: $hataSayi');
      
      return yuklenenSayi;
    } catch (e) {
      print('❌ Veri yükleme hatası: $e');
      return 0;
    }
  }

  /// Tarih formatını düzenle (çeşitli formatları destekler)
  String _formatTarih(dynamic tarihInput) {
    if (tarihInput == null) return _getBugunTarihi();
    
    String tarihStr = tarihInput.toString().trim();
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
  String _formatDurum(String durum) {
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
  String _getBugunTarihi() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

}