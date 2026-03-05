import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/kullanici.dart';
import 'email_servisi.dart';

class KimlkiDogrulamaSistemi {
  static final KimlkiDogrulamaSistemi _instance = KimlkiDogrulamaSistemi._internal();
  factory KimlkiDogrulamaSistemi() => _instance;
  KimlkiDogrulamaSistemi._internal();

  // Firestore referansı
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'kullanicilar';
  
  // Cache kontrolü
  bool _initialized = false;

  Kullanici? _aktifoKullanici;
  Kullanici? get aktifoKullanici => _aktifoKullanici;

  // Kullanıcı listesi (yerel cache)
  List<Kullanici> _kullanicilar = [];
  
  // Email servisi
  final EmailServisi _emailServisi = EmailServisi();
  
  // Geçici doğrulama kodlarını saklamak için
  final Map<String, String> _dogrulamaKodlari = {};

  // SharedPreferences anahtarı (sadece aktif kullanıcı için)
  static const String _aktifKullaniciKey = 'aktifKullanici';

  // Başlangıçta verileri yükle
  Future<void> init() async {
    if (_initialized) return; // Zaten yüklendiyse skip
    await _verileriYukle();
    _initialized = true;
  }

  // Verileri Firestore'dan yükle (cache öncelikli)
  Future<void> _verileriYukle() async {
    try {
      // Önce cache'den oku
      final snapshot = await _firestore
          .collection(_collectionName)
          .get(const GetOptions(source: Source.cache))
          .catchError((_) => _firestore.collection(_collectionName).get());
      
      _kullanicilar = snapshot.docs.map((doc) => Kullanici.fromJson(doc.data())).toList();

      // Aktif kullanıcıyı SharedPreferences'tan yükle (yerel oturum)
      final prefs = await SharedPreferences.getInstance();
      final aktifKullaniciJson = prefs.getString(_aktifKullaniciKey);
      if (aktifKullaniciJson != null) {
        final aktifData = jsonDecode(aktifKullaniciJson);
        // Firestore'daki güncel veriyi al
        _aktifoKullanici = _kullanicilar.firstWhere(
          (k) => k.email == aktifData['email'],
          orElse: () => Kullanici.fromJson(aktifData),
        );
      }

      print('✅ Kullanıcılar yüklendi: ${_kullanicilar.length} kullanıcı');
    } catch (e) {
      print('❌ Veri yükleme hatası: $e');
    }
  }

  // Aktif kullanıcıyı kaydet (sadece yerel)
  Future<void> _aktifKullaniciKaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_aktifoKullanici != null) {
        final aktifKullaniciJson = jsonEncode(_aktifoKullanici!.toJson());
        await prefs.setString(_aktifKullaniciKey, aktifKullaniciJson);
      } else {
        await prefs.remove(_aktifKullaniciKey);
      }
    } catch (e) {
      print('❌ Aktif kullanıcı kaydetme hatası: $e');
    }
  }

  // Verileri yenile
  Future<void> yenile() async {
    await _verileriYukle();
  }

  // Email veya kullanıcı adı ile giriş yap
  Future<bool> girisYap(String emailVeyaKullaniciAdi, String sifre) async {
    try {
      // Önce cache'den kontrol et (hızlı)
      Kullanici? kullanici = _kullaniciBul(emailVeyaKullaniciAdi, sifre);
      
      // Cache'de yoksa Firestore'dan güncelle ve tekrar dene
      if (kullanici == null) {
        await _verileriYukle().timeout(const Duration(seconds: 5));
        kullanici = _kullaniciBul(emailVeyaKullaniciAdi, sifre);
      }
      
      if (kullanici != null) {
        _aktifoKullanici = kullanici;
        await _aktifKullaniciKaydet();
        print('✅ Giriş başarılı: $emailVeyaKullaniciAdi');
        return true;
      }
      
      print('❌ Giriş başarısız: $emailVeyaKullaniciAdi');
      return false;
    } catch (e) {
      print('❌ Giriş hatası: $e');
      return false;
    }
  }
  
  // Kullanıcı bul (helper)
  Kullanici? _kullaniciBul(String emailVeyaKullaniciAdi, String sifre) {
    try {
      return _kullanicilar.firstWhere(
        (k) => (k.email == emailVeyaKullaniciAdi || k.kullaniciAdi == emailVeyaKullaniciAdi) && k.sifre == sifre,
      );
    } catch (e) {
      return null;
    }
  }

  // Çıkış yap
  Future<void> cikisYap() async {
    _aktifoKullanici = null;
    await _aktifKullaniciKaydet();
    print('✅ Çıkış yapıldı');
  }

  // Email var mı kontrol et (önce cache, sonra Firebase)
  bool emailVarMi(String email) {
    return _kullanicilar.any((k) => k.email.toLowerCase() == email.toLowerCase());
  }

  // Email var mı kontrol et - Firebase'den (asenkron, daha güvenilir)
  Future<bool> emailVarMiFirebase(String email) async {
    try {
      // Önce cache'den kontrol
      if (_kullanicilar.any((k) => k.email.toLowerCase() == email.toLowerCase())) {
        return true;
      }
      
      // Firebase'den kontrol
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('email', isEqualTo: email.toLowerCase())
          .get()
          .timeout(const Duration(seconds: 5));
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Email kontrol hatası: $e');
      // Hata durumunda cache'e güven
      return _kullanicilar.any((k) => k.email.toLowerCase() == email.toLowerCase());
    }
  }

  // Email ile kullanıcı bul
  Kullanici? kullaniciEmailBul(String email) {
    try {
      return _kullanicilar.firstWhere((k) => k.email.toLowerCase() == email.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  // Kullanıcı adı var mı kontrol et (önce cache, sonra Firebase)
  bool kullaniciAdiVarMi(String kullaniciAdi) {
    return _kullanicilar.any((k) => k.kullaniciAdi.toLowerCase() == kullaniciAdi.toLowerCase());
  }

  // Kullanıcı adı var mı kontrol et - Firebase'den (asenkron, daha güvenilir)
  Future<bool> kullaniciAdiVarMiFirebase(String kullaniciAdi) async {
    try {
      // Önce cache'den kontrol
      if (_kullanicilar.any((k) => k.kullaniciAdi.toLowerCase() == kullaniciAdi.toLowerCase())) {
        return true;
      }
      
      // Firebase'den kontrol
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('kullaniciAdi', isEqualTo: kullaniciAdi)
          .get()
          .timeout(const Duration(seconds: 5));
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Kullanıcı adı kontrol hatası: $e');
      // Hata durumunda cache'e güven
      return _kullanicilar.any((k) => k.kullaniciAdi.toLowerCase() == kullaniciAdi.toLowerCase());
    }
  }

  // Kullanıcı adı var mı kontrol et (eski - geriye uyumluluk için)
  // Bu fonksiyon kaldırıldı, yukarıdaki kullaniciAdiVarMi kullanılıyor

  // Email veya kullanıcı adı var mı kontrol et
  bool emailVeyaKullaniciAdiVarMi(String emailVeyaKullaniciAdi) {
    final lower = emailVeyaKullaniciAdi.toLowerCase();
    return _kullanicilar.any((k) => 
      k.email.toLowerCase() == lower || k.kullaniciAdi.toLowerCase() == lower
    );
  }

  // Şifre kontrolü
  Future<bool> sifreKontrolEt(String emailVeyaKullaniciAdi, String sifre) async {
    try {
      return _kullanicilar.any((k) => 
        (k.email == emailVeyaKullaniciAdi || k.kullaniciAdi == emailVeyaKullaniciAdi) && 
        k.sifre == sifre
      );
    } catch (e) {
      return false;
    }
  }

  // Email'i normalize et (tutarlılık için)
  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  // Doğrulama kodu gönder
  Future<bool> dogrulamaKoduGonder(String email) async {
    try {
      final temizEmail = _normalizeEmail(email);
      
      // 6 haneli GERÇEK rastgele kod oluştur
      final random = Random.secure();
      final kod = (100000 + random.nextInt(900000)).toString();
      
      // Eski kodu temizle ve yeni kodu sakla
      _dogrulamaKodlari.remove(temizEmail);
      _dogrulamaKodlari[temizEmail] = kod;
      
      print('📧 Yeni kod oluşturuldu: $temizEmail -> $kod');
      print('📧 Map durumu: $_dogrulamaKodlari');
      
      // Email gönder
      final basarili = await _emailServisi.dogrulamaKoduGonder(email, kod);
      
      if (basarili) {
        print('✅ Doğrulama kodu gönderildi: $temizEmail -> $kod');
        
        // 10 dakika sonra kodu temizle (sadece bu kod hala geçerliyse)
        final kaydedilenKod = kod;
        Future.delayed(const Duration(minutes: 10), () {
          if (_dogrulamaKodlari[temizEmail] == kaydedilenKod) {
            _dogrulamaKodlari.remove(temizEmail);
            print('⏰ Kod süresi doldu ve silindi: $temizEmail');
          }
        });
        
        return true;
      } else {
        print('❌ Doğrulama kodu gönderilemedi: $temizEmail');
        // Email gönderilemezse kodu sil
        _dogrulamaKodlari.remove(temizEmail);
        return false;
      }
    } catch (e) {
      print('❌ Doğrulama kodu gönderme hatası: $e');
      return false;
    }
  }

  // Doğrulama kodunu doğrula
  Future<bool> dogrulamaKoduDogrula(String email, String kod) async {
    try {
      final temizEmail = _normalizeEmail(email);
      final temizKod = kod.trim();
      final dogruKod = _dogrulamaKodlari[temizEmail];
      
      print('🔍 Kod doğrulama başladı');
      print('🔍 Gelen email: "$email" -> Normalize: "$temizEmail"');
      print('🔍 Girilen kod: "$temizKod"');
      print('🔍 Beklenen kod: "$dogruKod"');
      print('🔍 Map içeriği: $_dogrulamaKodlari');
      print('🔍 Map keys: ${_dogrulamaKodlari.keys.toList()}');
      
      if (dogruKod == null) {
        print('❌ Bu email için kayıtlı kod bulunamadı: $temizEmail');
        return false;
      }
      
      if (dogruKod == temizKod) {
        _dogrulamaKodlari.remove(temizEmail);
        print('✅ Doğrulama kodu doğrulandı: $temizEmail');
        return true;
      } else {
        print('❌ Kodlar eşleşmiyor: beklenen="$dogruKod", girilen="$temizKod"');
        return false;
      }
    } catch (e) {
      print('❌ Doğrulama hatası: $e');
      return false;
    }
  }

  // Yeni kullanıcı kaydet - detaylı hata mesajı ile
  // Dönüş: {'basarili': bool, 'mesaj': String, 'hataKodu': String?}
  Future<Map<String, dynamic>> yeniKullaniciKaydetDetayli({
    required String email,
    required String kullaniciAdi,
    required String adSoyad,
    required String sifre,
  }) async {
    try {
      final temizEmail = email.trim().toLowerCase();
      final temizKullaniciAdi = kullaniciAdi.trim();
      
      // Email ve kullanıcı adı kontrolünü PARALEL yap (2x daha hızlı)
      final kontroller = await Future.wait([
        _firestore
            .collection(_collectionName)
            .where('email', isEqualTo: temizEmail)
            .get(),
        _firestore
            .collection(_collectionName)
            .where('kullaniciAdi', isEqualTo: temizKullaniciAdi)
            .get(),
      ]).timeout(const Duration(seconds: 5));
      
      if (kontroller[0].docs.isNotEmpty) {
        print('❌ Email zaten kayıtlı: $temizEmail');
        return {
          'basarili': false,
          'mesaj': 'Bu email adresi zaten kayıtlı!',
          'hataKodu': 'EMAIL_EXISTS',
        };
      }

      if (kontroller[1].docs.isNotEmpty) {
        print('❌ Kullanıcı adı zaten kayıtlı: $temizKullaniciAdi');
        return {
          'basarili': false,
          'mesaj': 'Bu kullanıcı adı zaten alınmış!',
          'hataKodu': 'USERNAME_EXISTS',
        };
      }

      // Yeni kullanıcı oluştur
      final yeniKullanici = Kullanici(
        email: temizEmail,
        kullaniciAdi: temizKullaniciAdi,
        adSoyad: adSoyad.trim(),
        sifre: sifre,
      );

      // Firestore'a kaydet - 5 saniye timeout
      await _firestore
          .collection(_collectionName)
          .doc(temizEmail)
          .set(yeniKullanici.toJson())
          .timeout(const Duration(seconds: 5));
      
      // Yerel cache güncelle
      _kullanicilar.add(yeniKullanici);
      
      // Otomatik giriş yap
      _aktifoKullanici = yeniKullanici;
      await _aktifKullaniciKaydet();
      
      print('✅ Yeni kullanıcı kaydedildi: $temizKullaniciAdi ($adSoyad - $temizEmail)');
      return {
        'basarili': true,
        'mesaj': 'Kayıt başarılı!',
        'hataKodu': null,
      };
    } catch (e) {
      print('❌ Kayıt hatası: $e');
      return {
        'basarili': false,
        'mesaj': 'Bağlantı hatası. Lütfen tekrar deneyiniz.',
        'hataKodu': 'CONNECTION_ERROR',
      };
    }
  }

  // Yeni kullanıcı kaydet (eski fonksiyon - geriye uyumluluk)
  Future<bool> yeniKullaniciKaydet({
    required String email,
    required String kullaniciAdi,
    required String adSoyad,
    required String sifre,
  }) async {
    try {
      final temizEmail = email.trim().toLowerCase();
      final temizKullaniciAdi = kullaniciAdi.trim();
      
      // Email ve kullanıcı adı kontrolünü PARALEL yap (2x daha hızlı)
      final kontroller = await Future.wait([
        _firestore
            .collection(_collectionName)
            .where('email', isEqualTo: temizEmail)
            .get(),
        _firestore
            .collection(_collectionName)
            .where('kullaniciAdi', isEqualTo: temizKullaniciAdi)
            .get(),
      ]).timeout(const Duration(seconds: 5));
      
      if (kontroller[0].docs.isNotEmpty) {
        print('❌ Email zaten kayıtlı: $temizEmail');
        return false;
      }

      if (kontroller[1].docs.isNotEmpty) {
        print('❌ Kullanıcı adı zaten kayıtlı: $temizKullaniciAdi');
        return false;
      }

      // Yeni kullanıcı oluştur
      final yeniKullanici = Kullanici(
        email: email,
        kullaniciAdi: kullaniciAdi,
        adSoyad: adSoyad,
        sifre: sifre,
      );

      // Firestore'a kaydet - 5 saniye timeout
      await _firestore
          .collection(_collectionName)
          .doc(email)
          .set(yeniKullanici.toJson())
          .timeout(const Duration(seconds: 5));
      
      // Yerel cache güncelle
      _kullanicilar.add(yeniKullanici);
      
      // Otomatik giriş yap
      _aktifoKullanici = yeniKullanici;
      await _aktifKullaniciKaydet();
      
      print('✅ Yeni kullanıcı kaydedildi: $kullaniciAdi ($adSoyad - $email)');
      return true;
    } catch (e) {
      print('❌ Kayıt hatası: $e');
      return false;
    }
  }

  // Kullanıcı bilgilerini güncelle
  Future<bool> kullaniciGuncelle({
    required String yeniEmail,
    required String yeniKullaniciAdi,
    required String yeniAdSoyad,
    required String eskiSifre,
    String? yeniSifre,
  }) async {
    if (_aktifoKullanici == null) {
      print('❌ Güncelleme hatası: Aktif kullanıcı yok');
      return false;
    }

    // Eski şifreyi doğrula
    if (_aktifoKullanici!.sifre != eskiSifre) {
      print('❌ Güncelleme hatası: Şifre yanlış');
      return false;
    }

    try {
      final eskiEmail = _aktifoKullanici!.email;

      // Email değiştiyse kontrol et
      if (yeniEmail != eskiEmail) {
        final emailKontrol = await _firestore
            .collection(_collectionName)
            .where('email', isEqualTo: yeniEmail)
            .get();
        
        if (emailKontrol.docs.isNotEmpty) {
          print('❌ Güncelleme hatası: Yeni email zaten kullanılıyor');
          return false;
        }
      }

      // Kullanıcı adı değiştiyse kontrol et
      if (yeniKullaniciAdi != _aktifoKullanici!.kullaniciAdi) {
        final kullaniciAdiKontrol = await _firestore
            .collection(_collectionName)
            .where('kullaniciAdi', isEqualTo: yeniKullaniciAdi)
            .get();
        
        if (kullaniciAdiKontrol.docs.isNotEmpty) {
          print('❌ Güncelleme hatası: Yeni kullanıcı adı zaten kullanılıyor');
          return false;
        }
      }

      final yeniSifreDeger = yeniSifre ?? _aktifoKullanici!.sifre;

      final guncelKullanici = Kullanici(
        email: yeniEmail,
        kullaniciAdi: yeniKullaniciAdi,
        adSoyad: yeniAdSoyad,
        sifre: yeniSifreDeger,
      );

      // Eski dokümanı sil ve yenisini ekle (email değiştiyse)
      if (yeniEmail != eskiEmail) {
        await _firestore.collection(_collectionName).doc(eskiEmail).delete();
      }
      await _firestore.collection(_collectionName).doc(yeniEmail).set(guncelKullanici.toJson());

      // Yerel cache güncelle
      final index = _kullanicilar.indexWhere((k) => k.email == eskiEmail);
      if (index != -1) {
        _kullanicilar[index] = guncelKullanici;
      }
      
      _aktifoKullanici = guncelKullanici;
      await _aktifKullaniciKaydet();
      
      print('✅ Kullanıcı bilgileri güncellendi: $yeniKullaniciAdi');
      return true;
    } catch (e) {
      print('❌ Güncelleme hatası: $e');
      return false;
    }
  }

  // Oturum açık mı kontrol et
  bool get oturumAcikMi => _aktifoKullanici != null;

  // Tüm kullanıcıları al
  List<Kullanici> get tumKullanicilar => List<Kullanici>.from(_kullanicilar);

  // Şifre sıfırlama
  Future<bool> sifreSifirla(String emailVeyaKullaniciAdi) async {
    try {
      Kullanici? kullanici;
      
      // Email veya kullanıcı adı ile bul
      try {
        if (emailVeyaKullaniciAdi.contains('@')) {
          kullanici = _kullanicilar.firstWhere((k) => k.email == emailVeyaKullaniciAdi);
        } else {
          kullanici = _kullanicilar.firstWhere((k) => k.kullaniciAdi == emailVeyaKullaniciAdi);
        }
      } catch (e) {
        print('❌ Kullanıcı bulunamadı: $emailVeyaKullaniciAdi');
        return false;
      }

      // Yeni şifre oluştur
      final yeniSifre = _yeniSifreOlustur();
      
      // Email gönder
      final gonderildi = await _emailServisi.yeniSifreGonder(kullanici.email, yeniSifre);
      
      if (gonderildi) {
        // Firestore'da şifreyi güncelle
        await _firestore.collection(_collectionName).doc(kullanici.email).update({
          'sifre': yeniSifre,
        });
        
        // Yerel cache güncelle
        kullanici.sifre = yeniSifre;
        
        print('✅ Şifre sıfırlandı: ${kullanici.email}');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Şifre sıfırlama hatası: $e');
      return false;
    }
  }

  // Rastgele şifre oluştur
  String _yeniSifreOlustur() {
    const karakterler = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String sifre = '';
    for (int i = 0; i < 8; i++) {
      sifre += karakterler[(random + i * 7) % karakterler.length];
    }
    return sifre;
  }

  // Tüm kullanıcı verilerini temizle
  Future<void> tumVerileriTemizle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_aktifKullaniciKey);
      
      // Firestore'dan da sil
      final batch = _firestore.batch();
      final docs = await _firestore.collection(_collectionName).get();
      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      _kullanicilar.clear();
      _aktifoKullanici = null;
      print('🗑️ Tüm kullanıcı verileri temizlendi');
    } catch (e) {
      print('❌ Temizleme hatası: $e');
    }
  }

  // Tüm kullanıcıları listele (debug için)
  void kullanicilariListele() {
    print('📊 Kayıtlı Kullanıcılar:');
    for (var k in _kullanicilar) {
      print('   - ${k.kullaniciAdi} | ${k.adSoyad} | ${k.email}');
    }
  }
}
