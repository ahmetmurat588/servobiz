import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bildirim_servisi.dart';

/// Arka plan mesaj işleyici (top-level function olmalı)
@pragma('vm:entry-point')
Future<void> _arkaPlanMesajIsleyici(RemoteMessage message) async {
  print('📩 Arka plan mesajı alındı: ${message.messageId}');
  // Arka planda gelen mesajlar için işlem yapılabilir
}

/// Firebase Cloud Messaging Servisi
/// Tüm cihazlara push bildirim göndermek için kullanılır
class FCMServisi {
  static final FCMServisi _instance = FCMServisi._internal();
  factory FCMServisi() => _instance;
  FCMServisi._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // BildirimServisi referansı (getter ile döngüsel bağımlılık önlenir)
  BildirimServisi get _bildirimServisi => BildirimServisi();
  
  String? _token;
  String? get token => _token;
  String? _kullaniciEmail;
  
  bool _initialized = false;
  StreamSubscription? _bildirimDinleyici;

  /// FCM'i başlat ve token'ı kaydet
  Future<void> init(String? kullaniciEmail) async {
    if (_initialized) return;
    
    try {
      // Arka plan mesaj işleyiciyi ayarla
      FirebaseMessaging.onBackgroundMessage(_arkaPlanMesajIsleyici);
      
      // Bildirim izni iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      print('📱 Bildirim izni durumu: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // FCM Token al
        _token = await _messaging.getToken();
        print('📱 FCM Token: $_token');
        
        // Token'ı Firestore'a kaydet
        if (_token != null && kullaniciEmail != null) {
          await _tokenKaydet(kullaniciEmail, _token!);
        }
        
        // Token yenilendiğinde güncelle
        _messaging.onTokenRefresh.listen((newToken) {
          _token = newToken;
          print('📱 FCM Token yenilendi: $newToken');
          if (kullaniciEmail != null) {
            _tokenKaydet(kullaniciEmail, newToken);
          }
        });
        
        // Ön plandayken gelen mesajları dinle
        FirebaseMessaging.onMessage.listen(_onPlanMesaji);
        
        // Arka plandayken bildirime tıklandığında
        FirebaseMessaging.onMessageOpenedApp.listen(_onArkaPlanMesaji);
        
        // Uygulama kapalıyken bildirime tıklanarak açıldıysa
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _onArkaPlanMesaji(initialMessage);
        }
        
        _initialized = true;
        
        // Firestore bildirim dinleyicisini başlat
        _kullaniciEmail = kullaniciEmail;
        _bildirimDinle();
        
        print('✅ FCM Servisi başlatıldı');
      } else {
        print('⚠️ Bildirim izni reddedildi');
        // İzin olmasa bile Firestore dinleyicisini başlat
        _kullaniciEmail = kullaniciEmail;
        _bildirimDinle();
      }
    } catch (e) {
      print('❌ FCM başlatma hatası: $e');
    }
  }

  /// Firestore'daki bildirimler koleksiyonunu gerçek zamanlı dinle
  /// Diğer cihazlardan gelen bildirimleri yerel bildirim olarak gösterir
  void _bildirimDinle() {
    _bildirimDinleyici?.cancel();
    
    _bildirimDinleyici = _firestore
        .collection('bildirimler')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          
          // Kendi gönderdiğimiz bildirimi atla
          final gonderenToken = data['gonderenToken'] as String?;
          if (gonderenToken == _token && _token != null) continue;
          
          // Hedefli bildirimse sadece hedef kullanıcıya göster
          final hedefEmail = data['hedefEmail'] as String?;
          if (hedefEmail != null && hedefEmail != _kullaniciEmail) continue;
          
          // Yerel bildirim göster
          final baslik = data['baslik'] as String? ?? 'Bildirim';
          final mesaj = data['mesaj'] as String? ?? '';
          final tip = data['tip'] as String? ?? 'genel';
          final bildirimData = Map<String, dynamic>.from(data['data'] ?? {});
          
          _yerelBildirimGoster(baslik, mesaj, {...bildirimData, 'tip': tip});
          print('📩 Firestore bildirim alındı: $baslik');
        }
      }
    }, onError: (e) {
      print('❌ Bildirim dinleme hatası: $e');
    });
    
    print('👂 Firestore bildirim dinleyicisi başlatıldı');
  }

  /// Token'ı Firestore'a kaydet
  Future<void> _tokenKaydet(String email, String token) async {
    try {
      await _firestore.collection('fcm_tokens').doc(email).set({
        'token': token,
        'email': email,
        'platform': _getPlatform(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ FCM Token Firestore\'a kaydedildi');
    } catch (e) {
      print('❌ Token kaydetme hatası: $e');
    }
  }
  
  /// Platform bilgisi al
  String _getPlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// Token'ı Firestore'dan sil (çıkış yapıldığında)
  Future<void> tokenSil(String email) async {
    try {
      await _firestore.collection('fcm_tokens').doc(email).delete();
      print('✅ FCM Token silindi');
    } catch (e) {
      print('❌ Token silme hatası: $e');
    }
  }

  /// Ön planda gelen mesaj
  void _onPlanMesaji(RemoteMessage message) {
    print('📩 Ön plan mesajı: ${message.notification?.title}');
    
    // Yerel bildirim göster (uygulama açıkken FCM bildirimi görünmez)
    if (message.notification != null) {
      _yerelBildirimGoster(
        message.notification!.title ?? 'Bildirim',
        message.notification!.body ?? '',
        message.data,
      );
    }
  }

  /// Arka plan mesajı (kullanıcı bildirime tıkladığında)
  void _onArkaPlanMesaji(RemoteMessage message) {
    print('📩 Arka plan mesajı açıldı: ${message.data}');
    
    // Gerekirse ilgili sayfaya yönlendirme yapılabilir
    final data = message.data;
    if (data.containsKey('servoBizNo')) {
      // Cihaz detay sayfasına yönlendir
      print('Cihaz açılacak: ${data['servoBizNo']}');
    }
  }

  /// Yerel bildirim göster
  Future<void> _yerelBildirimGoster(
    String baslik,
    String mesaj,
    Map<String, dynamic> data,
  ) async {
    final tip = data['tip'] ?? 'genel';
    
    switch (tip) {
      case 'cihaz_eklendi':
        await _bildirimServisi.cihazKaydedildi(
          data['servoBizNo'] ?? '',
          mesaj,
          kaydeden: data['kaydeden'],
          sendPush: false,
        );
        break;
      case 'durum_degisti':
        await _bildirimServisi.cihazDurumuGuncellendi(
          data['servoBizNo'] ?? '',
          data['eskiDurum'] ?? '',
          data['yeniDurum'] ?? '',
          data['guncelleyen'] ?? '',
          sendPush: false,
        );
        break;
      case 'onay_istegi':
        await _bildirimServisi.onayIstegiOlusturuldu(
          data['servoBizNo'] ?? '',
          data['istenenDurum'] ?? '',
          data['isteyen'] ?? '',
          sendPush: false,
        );
        break;
      case 'onay_sonucu':
        await _bildirimServisi.onayIstegiSonuclandi(
          data['servoBizNo'] ?? '',
          data['durum'] ?? '',
          data['onaylandi'] == 'true',
          data['islemYapan'] ?? '',
          sendPush: false,
        );
        break;
      default:
        // Genel bildirim için varsayılan gösterim
        await _bildirimServisi.cihazKaydedildi(baslik, mesaj, sendPush: false);
    }
  }

  /// Tüm kullanıcılara bildirim gönder
  /// NOT: Bu, Firestore'a bildirim kaydı ekler
  /// Cloud Function bu kaydı tespit edip tüm token'lara push gönderir
  Future<void> bildirimGonder({
    required String baslik,
    required String mesaj,
    required String tip,
    Map<String, dynamic>? data,
    String? hedefEmail, // Belirli bir kullanıcıya göndermek için
  }) async {
    try {
      final bildirimData = {
        'baslik': baslik,
        'mesaj': mesaj,
        'tip': tip,
        'data': data ?? {},
        'hedefEmail': hedefEmail, // null ise herkese
        'createdAt': FieldValue.serverTimestamp(),
        'gonderildi': false,
        'gonderenToken': _token,
      };
      
      await _firestore.collection('bildirimler').add(bildirimData);
      print('✅ Bildirim Firestore\'a kaydedildi');
    } catch (e) {
      print('❌ Bildirim gönderme hatası: $e');
    }
  }

  /// Cihaz eklendi bildirimi gönder
  Future<void> cihazEklendiBildirimi({
    required String servoBizNo,
    required String markaModel,
    required String kaydeden,
  }) async {
    await bildirimGonder(
      baslik: 'Yeni Cihaz Kaydedildi',
      mesaj: '$servoBizNo - $markaModel',
      tip: 'cihaz_eklendi',
      data: {
        'servoBizNo': servoBizNo,
        'markaModel': markaModel,
        'kaydeden': kaydeden,
      },
    );
  }

  /// Durum değişti bildirimi gönder
  Future<void> durumDegistiBildirimi({
    required String servoBizNo,
    required String eskiDurum,
    required String yeniDurum,
    required String guncelleyen,
  }) async {
    await bildirimGonder(
      baslik: 'Cihaz Durumu Güncellendi',
      mesaj: '$servoBizNo: $eskiDurum → $yeniDurum',
      tip: 'durum_degisti',
      data: {
        'servoBizNo': servoBizNo,
        'eskiDurum': eskiDurum,
        'yeniDurum': yeniDurum,
        'guncelleyen': guncelleyen,
      },
    );
  }

  /// Onay isteği bildirimi gönder
  Future<void> onayIstegiBildirimi({
    required String servoBizNo,
    required String istenenDurum,
    required String isteyen,
    String? hedefOnaylayici, // Belirli onaylayıcıya göndermek için
  }) async {
    await bildirimGonder(
      baslik: 'Yeni Onay İsteği',
      mesaj: '$servoBizNo için "$istenenDurum" onayı bekleniyor',
      tip: 'onay_istegi',
      data: {
        'servoBizNo': servoBizNo,
        'istenenDurum': istenenDurum,
        'isteyen': isteyen,
      },
      hedefEmail: hedefOnaylayici,
    );
  }

  /// Onay sonucu bildirimi gönder
  Future<void> onaySonucuBildirimi({
    required String servoBizNo,
    required String durum,
    required bool onaylandi,
    required String islemYapan,
    required String hedefKullanici,
  }) async {
    await bildirimGonder(
      baslik: onaylandi ? 'Onay İsteği Kabul Edildi' : 'Onay İsteği Reddedildi',
      mesaj: onaylandi 
          ? '$servoBizNo "$durum" olarak güncellendi'
          : '$servoBizNo için onay isteği reddedildi',
      tip: 'onay_sonucu',
      data: {
        'servoBizNo': servoBizNo,
        'durum': durum,
        'onaylandi': onaylandi.toString(),
        'islemYapan': islemYapan,
      },
      hedefEmail: hedefKullanici,
    );
  }

  /// Tüm kayıtlı token'ları getir (debug için)
  Future<List<Map<String, dynamic>>> tumTokenlariGetir() async {
    try {
      final snapshot = await _firestore.collection('fcm_tokens').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ Token getirme hatası: $e');
      return [];
    }
  }

  /// Dinleyiciyi durdur
  void dispose() {
    _bildirimDinleyici?.cancel();
    _bildirimDinleyici = null;
  }
}
