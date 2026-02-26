import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cihaz.dart';
import '../models/islem_raporu.dart';

/// Merkezi Cihaz Yönetim Servisi - Firebase Firestore
/// Tüm cihazları gerçek zamanlı senkronize eder
class CihazServisi {
  static final CihazServisi _instance = CihazServisi._internal();
  factory CihazServisi() => _instance;
  CihazServisi._internal();

  // Firestore referansı - cache optimize
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'cihazlar';
  
  // Cache kontrolü
  bool _initialized = false;
  DateTime? _lastFetch;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  // Yerel cache
  List<Cihaz> _cihazlar = [];

  // Getter - cache'den döner
  List<Cihaz> get cihazlar => List<Cihaz>.from(_cihazlar);

  // Real-time stream
  Stream<List<Cihaz>> get cihazlarStream => _firestore
      .collection(_collectionName)
      .orderBy('servoBizNo')
      .snapshots()
      .map((snapshot) {
        _cihazlar = snapshot.docs.map((doc) => Cihaz.fromJson(doc.data())).toList();
        return _cihazlar;
      });

  /// Başlangıçta verileri yükle
  Future<void> init() async {
    if (_initialized) return; // Zaten yüklendiyse skip
    await _verileriYukle();
    _initialized = true;
  }

  /// Verileri Firestore'dan yükle (cache ile)
  Future<void> _verileriYukle({bool force = false}) async {
    // Cache hala geçerliyse Firestore'a gitme (force değilse)
    if (!force && _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheTimeout &&
        _cihazlar.isNotEmpty) {
      return;
    }
    
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      
      if (force) {
        // Zorla server'dan çek (yenileme için)
        snapshot = await _firestore
            .collection(_collectionName)
            .orderBy('servoBizNo')
            .get(const GetOptions(source: Source.server));
      } else {
        // Önce cache'den dene, hata olursa server'dan çek
        snapshot = await _firestore
            .collection(_collectionName)
            .orderBy('servoBizNo')
            .get(const GetOptions(source: Source.cache))
            .catchError((_) => _firestore.collection(_collectionName).orderBy('servoBizNo').get());
      }
      
      _cihazlar = snapshot.docs.map((doc) => Cihaz.fromJson(doc.data())).toList();
      _lastFetch = DateTime.now();
      print('✅ Cihazlar yüklendi: ${_cihazlar.length} cihaz (force: $force)');
    } catch (e) {
      print('❌ Cihaz yükleme hatası: $e');
    }
  }

  /// Verileri yenile (zorla server'dan çek)
  Future<void> yenile() async {
    await _verileriYukle(force: true);
  }

  /// Yeni cihaz ekle
  Future<bool> cihazEkle(Cihaz cihaz) async {
    try {
      // Aynı ServoBiz No ile cihaz var mı kontrol et
      final existing = await _firestore
          .collection(_collectionName)
          .where('servoBizNo', isEqualTo: cihaz.servoBizNo)
          .get();
      
      if (existing.docs.isNotEmpty) {
        print('❌ Bu ServoBiz No zaten mevcut');
        return false;
      }
      
      // Firestore'a ekle
      await _firestore.collection(_collectionName).doc(cihaz.servoBizNo).set(cihaz.toJson());
      
      // Yerel cache güncelle
      _cihazlar.add(cihaz);
      print('✅ Cihaz eklendi: ${cihaz.servoBizNo}');
      return true;
    } catch (e) {
      print('❌ Cihaz ekleme hatası: $e');
      return false;
    }
  }

  /// Cihaz durumunu güncelle
  Future<bool> durumGuncelle(
    String servoBizNo, 
    String yeniDurum, {
    String? notlar,
    String? yazanKullanici,
    String? yazanEmail,
  }) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(servoBizNo);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('❌ Cihaz bulunamadı: $servoBizNo');
        return false;
      }
      
      final mevcutCihaz = Cihaz.fromJson(doc.data()!);
      final eskiDurum = mevcutCihaz.durum;
      
      // İşlem raporu oluştur
      List<IslemRaporu> yeniRaporlar = List.from(mevcutCihaz.islemRaporlari);
      if (notlar != null && notlar.isNotEmpty && yazanKullanici != null) {
        final yeniRapor = IslemRaporu(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          icerik: notlar,
          yazanKullanici: yazanKullanici,
          yazanEmail: yazanEmail ?? '',
          tarih: DateTime.now(),
          eskiDurum: eskiDurum,
          yeniDurum: yeniDurum,
        );
        yeniRaporlar.add(yeniRapor);
      }
      
      final guncelCihaz = mevcutCihaz.copyWith(
        durum: yeniDurum,
        notlar: notlar ?? mevcutCihaz.notlar,
        sonGuncelleyen: yazanKullanici,
        sonDurumDegisiklikTarihi: DateTime.now(),
        islemRaporlari: yeniRaporlar,
      );
      
      await docRef.set(guncelCihaz.toJson());
      
      // Yerel cache güncelle
      final index = _cihazlar.indexWhere((c) => c.servoBizNo == servoBizNo);
      if (index != -1) {
        _cihazlar[index] = guncelCihaz;
      }
      
      print('✅ Cihaz durumu güncellendi: $servoBizNo -> $yeniDurum');
      return true;
    } catch (e) {
      print('❌ Durum güncelleme hatası: $e');
      return false;
    }
  }

  /// Cihaz bilgilerini güncelle
  Future<bool> cihazGuncelle(Cihaz guncelCihaz) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(guncelCihaz.servoBizNo)
          .set(guncelCihaz.toJson());
      
      // Yerel cache güncelle
      final index = _cihazlar.indexWhere((c) => c.servoBizNo == guncelCihaz.servoBizNo);
      if (index != -1) {
        _cihazlar[index] = guncelCihaz;
      }
      
      return true;
    } catch (e) {
      print('❌ Cihaz güncelleme hatası: $e');
      return false;
    }
  }

  /// Cihaz sil
  Future<bool> cihazSil(String servoBizNo) async {
    try {
      await _firestore.collection(_collectionName).doc(servoBizNo).delete();
      _cihazlar.removeWhere((c) => c.servoBizNo == servoBizNo);
      return true;
    } catch (e) {
      print('❌ Cihaz silme hatası: $e');
      return false;
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

  /// Firestore'dan cihaz bul (gerçek zamanlı)
  Future<Cihaz?> cihazBulAsync(String servoBizNo) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(servoBizNo).get();
      if (doc.exists) {
        return Cihaz.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Son ServoBiz No'yu al (yeni cihaz için)
  String sonrakiServoBizNo() {
    if (_cihazlar.isEmpty) {
      return '2506001';
    }
    
    try {
      // En yüksek numarayı bul
      int maxNo = 2506000;
      for (var cihaz in _cihazlar) {
        final no = int.tryParse(cihaz.servoBizNo) ?? 0;
        if (no > maxNo) maxNo = no;
      }
      return (maxNo + 1).toString();
    } catch (e) {
      return '2506001';
    }
  }

  /// Duruma göre cihazları filtrele
  List<Cihaz> durumFiltrele(String durum) {
    return _cihazlar.where((c) => c.durum == durum).toList();
  }

  /// Seri numarası ile cihaz ara (büyük/küçük harf duyarsız)
  List<Cihaz> seriNoIleCihazBul(String seriNo) {
    if (seriNo.isEmpty) return [];
    final aramaSeriNo = seriNo.trim().toLowerCase();
    return _cihazlar.where((c) => 
      c.seriNo.toLowerCase() == aramaSeriNo
    ).toList();
  }

  /// Marka/Model ve Firma ismi ile cihaz ara (büyük/küçük harf duyarsız)
  List<Cihaz> markaModelVeFirmaIleCihazBul(String markaModel, String firmaIsmi) {
    if (markaModel.isEmpty || firmaIsmi.isEmpty) return [];
    final aramaMarkaModel = markaModel.trim().toLowerCase();
    final aramaFirmaIsmi = firmaIsmi.trim().toLowerCase();
    return _cihazlar.where((c) => 
      c.markaModel.toLowerCase() == aramaMarkaModel &&
      (c.firmaIsmi ?? '').toLowerCase() == aramaFirmaIsmi
    ).toList();
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
      _cihazlar.clear();
      print('🗑️ Tüm cihaz verileri temizlendi');
    } catch (e) {
      print('❌ Temizleme hatası: $e');
    }
  }
}
