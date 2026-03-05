import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/onay_istegi.dart';
import 'cihaz_servisi.dart';
import 'yetkilendirme_sistemi.dart';
import 'kimlik_dogrulama.dart';

/// Onay Servisi
/// Yetkisiz durum değişikliği isteklerini yönetir
/// Firebase Firestore ile senkronize çalışır
class OnayServisi {
  static final OnayServisi _instance = OnayServisi._internal();
  factory OnayServisi() => _instance;
  OnayServisi._internal();

  // Firestore referansı
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'onay_istekleri';

  // Yerel cache
  List<OnayIstegi> _istekler = [];
  bool _initialized = false;

  final CihazServisi _cihazServisi = CihazServisi();
  final YetkilendirmeSistemi _yetkiSistemi = YetkilendirmeSistemi();
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();

  /// Servisi başlat
  Future<void> init() async {
    if (_initialized) return;
    await _yukle();
    _initialized = true;
  }

  /// Verileri yenile
  Future<void> yenile() async {
    await _yukle();
  }

  /// Tüm istekleri al
  List<OnayIstegi> get istekler => List.unmodifiable(_istekler);

  /// Bekleyen istekleri al
  List<OnayIstegi> get bekleyenIstekler =>
      _istekler.where((i) => i.durum == OnayDurumu.beklemede).toList();

  /// Kullanıcının bekleyen isteklerini al
  List<OnayIstegi> kullanicininIstekleri(String email) {
    return _istekler.where((i) => i.isteyenEmail == email).toList();
  }

  /// Onaylayabileceği istekleri al (durum bazlı)
  List<OnayIstegi> onaylayabilecekIstekler(String email) {
    return bekleyenIstekler.where((istek) {
      return _yetkiSistemi.durumOnaylayabilirMi(email, istek.istenenDurum);
    }).toList();
  }

  /// Real-time stream - bekleyen istekler
  Stream<List<OnayIstegi>> bekleyenIsteklerStream() {
    return _firestore
        .collection(_collectionName)
        .where('durum', isEqualTo: 'beklemede')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OnayIstegi.fromJson(doc.data())).toList();
    });
  }

  /// Yeni onay isteği oluştur
  Future<OnayIstegi> istekOlustur({
    required String cihazServoBizNo,
    required String mevcutDurum,
    required String istenenDurum,
    required String isteyenEmail,
    required String isteyenAd,
    String? not,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final istek = OnayIstegi(
      id: id,
      cihazServoBizNo: cihazServoBizNo,
      mevcutDurum: mevcutDurum,
      istenenDurum: istenenDurum,
      isteyenEmail: isteyenEmail,
      isteyenAd: isteyenAd,
      istekTarihi: DateTime.now(),
      not: not,
    );

    // Firestore'a kaydet
    await _firestore.collection(_collectionName).doc(id).set(istek.toJson());
    
    // Yerel cache güncelle
    _istekler.add(istek);
    
    print('✅ Onay isteği oluşturuldu: $cihazServoBizNo -> $istenenDurum');
    return istek;
  }

  /// İsteği onayla
  Future<bool> onayla(String istekId, String onaylayanEmail) async {
    try {
      // Firestore'dan isteği al
      final doc = await _firestore.collection(_collectionName).doc(istekId).get();
      if (!doc.exists) return false;

      final istek = OnayIstegi.fromJson(doc.data()!);

      // Onaylama yetkisi var mı?
      if (!_yetkiSistemi.durumOnaylayabilirMi(onaylayanEmail, istek.istenenDurum)) {
        return false;
      }

      // Onaylayan kullanıcının bilgilerini al
      final onaylayanKullanici = _auth.kullaniciEmailBul(onaylayanEmail);
      final onaylayanAd = onaylayanKullanici?.adSoyad ?? 'Bilinmeyen';

      // İşlem raporu metni oluştur (isteyen kişinin notu + onaylayan bilgisi)
      final raporMetni = '${istek.not ?? ''}\n\n[Onaylayan: $onaylayanAd]';

      // Cihaz durumunu güncelle
      final guncellendi = await _cihazServisi.durumGuncelle(
        istek.cihazServoBizNo,
        istek.istenenDurum,
        notlar: raporMetni,
      );

      if (!guncellendi) return false;

      // Firestore'da güncelle
      final guncelIstek = istek.copyWith(
        durum: OnayDurumu.onaylandi,
        onaylayanEmail: onaylayanEmail,
        onayTarihi: DateTime.now(),
      );
      await _firestore.collection(_collectionName).doc(istekId).set(guncelIstek.toJson());

      // Yerel cache güncelle
      final index = _istekler.indexWhere((i) => i.id == istekId);
      if (index != -1) {
        _istekler[index] = guncelIstek;
      }

      print('✅ Onay isteği onaylandı: $istekId');
      return true;
    } catch (e) {
      print('❌ Onay hatası: $e');
      return false;
    }
  }

  /// İsteği reddet
  Future<bool> reddet(String istekId, String reddedimEmail) async {
    try {
      // Firestore'dan isteği al
      final doc = await _firestore.collection(_collectionName).doc(istekId).get();
      if (!doc.exists) return false;

      final istek = OnayIstegi.fromJson(doc.data()!);

      // Reddetme yetkisi var mı?
      if (!_yetkiSistemi.durumOnaylayabilirMi(reddedimEmail, istek.istenenDurum)) {
        return false;
      }

      // Firestore'da güncelle
      final guncelIstek = istek.copyWith(
        durum: OnayDurumu.reddedildi,
        onaylayanEmail: reddedimEmail,
        onayTarihi: DateTime.now(),
      );
      await _firestore.collection(_collectionName).doc(istekId).set(guncelIstek.toJson());

      // Yerel cache güncelle
      final index = _istekler.indexWhere((i) => i.id == istekId);
      if (index != -1) {
        _istekler[index] = guncelIstek;
      }

      print('❌ Onay isteği reddedildi: $istekId');
      return true;
    } catch (e) {
      print('❌ Reddetme hatası: $e');
      return false;
    }
  }

  /// İsteği iptal et (sadece isteyen kişi)
  Future<bool> iptalEt(String istekId, String iptalEdenEmail) async {
    try {
      // Firestore'dan isteği al
      final doc = await _firestore.collection(_collectionName).doc(istekId).get();
      if (!doc.exists) return false;

      final istek = OnayIstegi.fromJson(doc.data()!);

      // Sadece isteyen kişi iptal edebilir
      if (istek.isteyenEmail != iptalEdenEmail) return false;
      if (istek.durum != OnayDurumu.beklemede) return false;

      // Firestore'dan sil
      await _firestore.collection(_collectionName).doc(istekId).delete();

      // Yerel cache güncelle
      _istekler.removeWhere((i) => i.id == istekId);

      print('🗑️ Onay isteği iptal edildi: $istekId');
      return true;
    } catch (e) {
      print('❌ İptal hatası: $e');
      return false;
    }
  }

  /// Cihaz için bekleyen istek var mı?
  OnayIstegi? cihazIcinBekleyenIstek(String servoBizNo) {
    try {
      return _istekler.firstWhere(
        (i) => i.cihazServoBizNo == servoBizNo && i.durum == OnayDurumu.beklemede,
      );
    } catch (e) {
      return null;
    }
  }

  /// Verileri Firestore'dan yükle (cache öncelikli)
  Future<void> _yukle() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .get(const GetOptions(source: Source.cache))
          .catchError((_) => _firestore.collection(_collectionName).get());
      _istekler = snapshot.docs.map((doc) => OnayIstegi.fromJson(doc.data())).toList();
      print('✅ Onay istekleri yüklendi: ${_istekler.length} istek');
    } catch (e) {
      print('❌ Onay istekleri yükleme hatası: $e');
    }
  }

  /// Tüm verileri temizle
  Future<void> tumVerileriTemizle() async {
    try {
      final batch = _firestore.batch();
      final docs = await _firestore.collection(_collectionName).get();
      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _istekler.clear();
      print('🗑️ Tüm onay istekleri temizlendi');
    } catch (e) {
      print('❌ Temizleme hatası: $e');
    }
  }
}
