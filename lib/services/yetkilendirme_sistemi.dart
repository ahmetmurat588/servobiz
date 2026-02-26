import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/yetki.dart';

/// Yetkilendirme Sistemi
/// Kullanıcıların hangi durumlara erişebileceğini yönetir
/// Firebase Firestore ile senkronize çalışır
class YetkilendirmeSistemi {
  static final YetkilendirmeSistemi _instance = YetkilendirmeSistemi._internal();
  factory YetkilendirmeSistemi() => _instance;
  YetkilendirmeSistemi._internal();

  // Firestore referansı
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _yetkilerCollection = 'kullanici_yetkileri';
  static const String _onaylayicilarCollection = 'durum_onaylayicilari';
  
  // Cache kontrolü
  bool _initialized = false;

  // Admin email - sadece bu email yetkilendirme değiştirebilir
  static const String adminEmail = 'servobizmuhasebe@gmail.com';

  // Tüm durumlar
  static const List<String> tumDurumlar = [
    'Lobide',
    'Atolye Sevk',
    'Test Ünitesi Sevk',
    'Teslime Hazır',
    'Çıkış Yapıldı',
  ];

  // Kullanıcı yetkileri (yerel cache)
  final Map<String, KullaniciYetkisi> _kullaniciYetkileri = {};

  // Durum bazlı onaylayanlar (durum -> onaylayan email listesi)
  final Map<String, List<String>> _durumOnaylayanlari = {};

  /// Başlangıçta verileri yükle
  Future<void> init() async {
    if (_initialized) return; // Zaten yüklendiyse skip
    await _verileriYukle();
    await demoYetkileriYukle();
    _initialized = true;
    print('✅ YetkilendirmeSistemi başlatıldı: ${_kullaniciYetkileri.length} kullanıcı yetkisi');
  }

  /// Verileri yenile
  Future<void> yenile() async {
    await _verileriYukle();
  }

  /// Verileri Firestore'dan yükle (cache öncelikli)
  Future<void> _verileriYukle() async {
    try {
      // Yetkileri yükle - cache öncelikli
      final yetkilerSnapshot = await _firestore
          .collection(_yetkilerCollection)
          .get(const GetOptions(source: Source.cache))
          .catchError((_) => _firestore.collection(_yetkilerCollection).get());
      _kullaniciYetkileri.clear();
      for (var doc in yetkilerSnapshot.docs) {
        _kullaniciYetkileri[doc.id] = KullaniciYetkisi.fromJson(doc.data());
      }

      // Onaylayıcıları yükle - cache öncelikli
      final onaylayicilarSnapshot = await _firestore
          .collection(_onaylayicilarCollection)
          .get(const GetOptions(source: Source.cache))
          .catchError((_) => _firestore.collection(_onaylayicilarCollection).get());
      _durumOnaylayanlari.clear();
      for (var doc in onaylayicilarSnapshot.docs) {
        final data = doc.data();
        _durumOnaylayanlari[doc.id] = List<String>.from(data['emailler'] ?? []);
      }

      print('✅ Yetkilendirme verileri yüklendi');
    } catch (e) {
      print('❌ Yetkilendirme veri yükleme hatası: $e');
    }
  }

  /// Demo veri ekle - sadece admin
  Future<void> demoYetkileriYukle() async {
    // Admin zaten varsa tekrar ekleme
    if (_kullaniciYetkileri.containsKey(adminEmail)) return;
    
    // Admin - tüm durumlar
    final adminYetki = KullaniciYetkisi(
      kullaniciEmail: adminEmail,
      erisilebilenDurumlar: List<String>.from(tumDurumlar),
      adminMi: true,
    );
    
    _kullaniciYetkileri[adminEmail] = adminYetki;
    
    // Firestore'a kaydet
    await _firestore.collection(_yetkilerCollection).doc(adminEmail).set(adminYetki.toJson());
  }

  /// Kullanıcının yetkilerini al
  KullaniciYetkisi? kullaniciYetkisiAl(String email) {
    return _kullaniciYetkileri[email];
  }

  /// Kullanıcı admin mi?
  bool adminMi(String email) {
    return email == adminEmail || (_kullaniciYetkileri[email]?.adminMi ?? false);
  }

  /// Kullanıcının erişebildiği durumları al
  List<String> erisilebilenDurumlariAl(String email) {
    final yetki = _kullaniciYetkileri[email];
    if (yetki == null) return <String>[];
    return List<String>.from(yetki.erisilebilenDurumlar);
  }

  /// Kullanıcının belirli bir duruma erişim yetkisi var mı?
  bool durumErisimYetkisiVarMi(String email, String durum) {
    final yetki = _kullaniciYetkileri[email];
    if (yetki == null) return false;
    return yetki.durumErisimYetkisiVarMi(durum);
  }

  /// Durum değişikliği yap
  Map<String, dynamic> durumDegistir({
    required String kullaniciEmail,
    required String cihazServoBizNo,
    required String mevcutDurum,
    required String yeniDurum,
  }) {
    final yetki = _kullaniciYetkileri[kullaniciEmail];
    
    if (yetki == null) {
      return {
        'basarili': false,
        'mesaj': 'Bu işlem için yetkiniz bulunmuyor.',
      };
    }

    // Yeni duruma erişim yetkisi var mı kontrol et
    if (!yetki.durumErisimYetkisiVarMi(yeniDurum)) {
      return {
        'basarili': false,
        'mesaj': 'Bu duruma erişim yetkiniz bulunmuyor.',
      };
    }

    return {
      'basarili': true,
      'yeniDurum': yeniDurum,
      'mesaj': 'Durum başarıyla güncellendi.',
    };
  }

  /// Kullanıcıya yetki ekle/güncelle (sadece admin)
  Future<bool> yetkiGuncelle(String adminEmailKontrol, String kullaniciEmail, List<String> durumlar) async {
    if (!adminMi(adminEmailKontrol)) return false;

    try {
      KullaniciYetkisi yeniYetki;
      
      if (_kullaniciYetkileri.containsKey(kullaniciEmail)) {
        yeniYetki = _kullaniciYetkileri[kullaniciEmail]!.copyWith(
          erisilebilenDurumlar: durumlar,
        );
      } else {
        yeniYetki = KullaniciYetkisi(
          kullaniciEmail: kullaniciEmail,
          erisilebilenDurumlar: durumlar,
        );
      }
      
      // Firestore'a kaydet
      await _firestore.collection(_yetkilerCollection).doc(kullaniciEmail).set(yeniYetki.toJson());
      
      // Yerel cache güncelle
      _kullaniciYetkileri[kullaniciEmail] = yeniYetki;
      
      print('✅ Yetki güncellendi: $kullaniciEmail');
      return true;
    } catch (e) {
      print('❌ Yetki güncelleme hatası: $e');
      return false;
    }
  }

  /// Kullanıcının tüm yetkilerini kaldır (sadece admin)
  Future<bool> yetkiKaldir(String adminEmailKontrol, String kullaniciEmail) async {
    if (!adminMi(adminEmailKontrol)) return false;
    if (kullaniciEmail == adminEmail) return false; // Admin yetkisi kaldırılamaz

    try {
      // Firestore'dan sil
      await _firestore.collection(_yetkilerCollection).doc(kullaniciEmail).delete();
      
      // Yerel cache güncelle
      _kullaniciYetkileri.remove(kullaniciEmail);
      
      print('✅ Yetki kaldırıldı: $kullaniciEmail');
      return true;
    } catch (e) {
      print('❌ Yetki kaldırma hatası: $e');
      return false;
    }
  }

  /// Kullanıcının tek bir yetkisini kaldır (sadece admin)
  Future<bool> tekYetkiKaldir(String adminEmailKontrol, String kullaniciEmail, String durum) async {
    if (!adminMi(adminEmailKontrol)) return false;
    if (kullaniciEmail == adminEmail) return false; // Admin yetkisi değiştirilemez

    final yetki = _kullaniciYetkileri[kullaniciEmail];
    if (yetki == null) return false;

    try {
      final mevcutDurumlar = List<String>.from(yetki.erisilebilenDurumlar);
      mevcutDurumlar.remove(durum);

      final guncelYetki = yetki.copyWith(
        erisilebilenDurumlar: mevcutDurumlar,
      );
      
      // Firestore'a kaydet
      await _firestore.collection(_yetkilerCollection).doc(kullaniciEmail).set(guncelYetki.toJson());
      
      // Yerel cache güncelle
      _kullaniciYetkileri[kullaniciEmail] = guncelYetki;
      
      return true;
    } catch (e) {
      print('❌ Tek yetki kaldırma hatası: $e');
      return false;
    }
  }

  /// Tüm kullanıcı yetkilerini al (admin için)
  Map<String, KullaniciYetkisi> tumYetkileriAl(String adminEmailKontrol) {
    if (!adminMi(adminEmailKontrol)) return {};
    return Map.from(_kullaniciYetkileri);
  }

  /// Kayıtlı kullanıcı emaillerini al
  List<String> kayitliKullanicilar() {
    return _kullaniciYetkileri.keys.toList();
  }

  /// Durum için onaylayan ekle (sadece admin)
  Future<bool> durumOnaylayanEkle(String adminEmailKontrol, String durum, String onaylayanEmail) async {
    if (!adminMi(adminEmailKontrol)) return false;
    
    try {
      if (!_durumOnaylayanlari.containsKey(durum)) {
        _durumOnaylayanlari[durum] = [];
      }
      
      if (!_durumOnaylayanlari[durum]!.contains(onaylayanEmail)) {
        _durumOnaylayanlari[durum]!.add(onaylayanEmail);
      }
      
      // Firestore'a kaydet
      await _firestore.collection(_onaylayicilarCollection).doc(durum).set({
        'emailler': _durumOnaylayanlari[durum],
      });
      
      return true;
    } catch (e) {
      print('❌ Onaylayan ekleme hatası: $e');
      return false;
    }
  }

  /// Durum için onaylayanı kaldır (sadece admin)
  Future<bool> durumOnaylayanKaldir(String adminEmailKontrol, String durum, String onaylayanEmail) async {
    if (!adminMi(adminEmailKontrol)) return false;
    
    try {
      if (_durumOnaylayanlari.containsKey(durum)) {
        _durumOnaylayanlari[durum]!.remove(onaylayanEmail);
      }
      
      // Firestore'a kaydet
      await _firestore.collection(_onaylayicilarCollection).doc(durum).set({
        'emailler': _durumOnaylayanlari[durum] ?? [],
      });
      
      return true;
    } catch (e) {
      print('❌ Onaylayan kaldırma hatası: $e');
      return false;
    }
  }

  /// Durum için onaylayanları al
  List<String> durumOnaylayanlariAl(String durum) {
    return List<String>.from(_durumOnaylayanlari[durum] ?? []);
  }

  /// Tüm durum onaylayanlarını al (admin için)
  Map<String, List<String>> tumDurumOnaylayanlariAl(String adminEmailKontrol) {
    if (!adminMi(adminEmailKontrol)) return {};
    return Map.from(_durumOnaylayanlari);
  }

  /// Kullanıcı belirli bir durumu onaylayabilir mi?
  bool durumOnaylayabilirMi(String email, String durum) {
    if (adminMi(email)) return true;
    return _durumOnaylayanlari[durum]?.contains(email) ?? false;
  }
}
