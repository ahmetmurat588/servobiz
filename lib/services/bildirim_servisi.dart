import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'fcm_servisi.dart';

class BildirimServisi {
  static final BildirimServisi _instance = BildirimServisi._internal();
  factory BildirimServisi() => _instance;
  BildirimServisi._internal();

  final FlutterLocalNotificationsPlugin _bildirimPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // FCM servisi referansı
  final FCMServisi _fcmServisi = FCMServisi();

  // Bildirim kanallari
  static const String _cihazKanalId = 'cihaz_kanali';
  static const String _onayKanalId = 'onay_kanali';
  static const String _genelKanalId = 'genel_kanali';

  /// Bildirim servisini baslat
  Future<void> init() async {
    // Android ayarlari
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS ayarlari
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _bildirimPlugin.initialize(initSettings);

    // Bildirim kanallarini olustur
    await _createNotificationChannels();
  }

  /// Bildirim kanallarini olustur
  Future<void> _createNotificationChannels() async {
    // Cihaz kanali
    const cihazKanal = AndroidNotificationChannel(
      _cihazKanalId,
      'Cihaz Bildirimleri',
      description: 'Cihaz kayıt ve güncelleme bildirimleri',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Onay kanali
    const onayKanal = AndroidNotificationChannel(
      _onayKanalId,
      'Onay Bildirimleri',
      description: 'Onay isteği bildirimleri',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Genel kanal
    const genelKanal = AndroidNotificationChannel(
      _genelKanalId,
      'Genel Bildirimler',
      description: 'Diğer bildirimler',
      importance: Importance.defaultImportance,
    );

    // Kanallari olustur
    await _bildirimPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(cihazKanal);

    await _bildirimPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(onayKanal);

    await _bildirimPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(genelKanal);
  }

  /// Cihaz kaydedildi bildirimi
  /// showLocal: Yerel bildirim göster (varsayılan: true)
  /// sendPush: Tüm cihazlara push bildirim gönder (varsayılan: true)
  Future<void> cihazKaydedildi(
    String servoBizNo, 
    String markaModel, {
    String? kaydeden,
    bool showLocal = true,
    bool sendPush = true,
  }) async {
    final mesaj = kaydeden != null 
        ? '$kaydeden yeni cihaz kaydetti:\n$servoBizNo - $markaModel'
        : 'ServoBiz No: $servoBizNo\n$markaModel';

    // Yerel bildirim göster
    if (showLocal) {
      final androidDetails = AndroidNotificationDetails(
        _cihazKanalId,
        'Cihaz Bildirimleri',
        channelDescription: 'Cihaz kayıt ve güncelleme bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        colorized: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(mesaj),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _bildirimPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Yeni Cihaz Kaydedildi',
        mesaj,
        notificationDetails,
      );
    }
    
    // Tüm cihazlara push bildirim gönder (FCM)
    if (sendPush && kaydeden != null) {
      await _fcmServisi.cihazEklendiBildirimi(
        servoBizNo: servoBizNo,
        markaModel: markaModel,
        kaydeden: kaydeden,
      );
    }
  }

  /// Cihaz durumu güncellendi bildirimi
  /// sendPush: Tüm cihazlara push bildirim gönder (varsayılan: true)
  Future<void> cihazDurumuGuncellendi(
    String servoBizNo,
    String eskiDurum,
    String yeniDurum,
    String guncelleyen, {
    bool showLocal = true,
    bool sendPush = true,
  }) async {
    final mesaj = '$servoBizNo\n$eskiDurum → $yeniDurum';

    // Yerel bildirim göster
    if (showLocal) {
      final androidDetails = AndroidNotificationDetails(
        _cihazKanalId,
        'Cihaz Bildirimleri',
        channelDescription: 'Cihaz kayıt ve güncelleme bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        colorized: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(mesaj),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _bildirimPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '$guncelleyen Cihaz Güncelledi',
        mesaj,
        notificationDetails,
      );
    }
    
    // Tüm cihazlara push bildirim gönder (FCM)
    if (sendPush) {
      await _fcmServisi.durumDegistiBildirimi(
        servoBizNo: servoBizNo,
        eskiDurum: eskiDurum,
        yeniDurum: yeniDurum,
        guncelleyen: guncelleyen,
      );
    }
  }

  /// Onay isteği oluşturuldu bildirimi
  /// sendPush: Tüm cihazlara push bildirim gönder (varsayılan: true)
  Future<void> onayIstegiOlusturuldu(
    String servoBizNo,
    String istenenDurum,
    String isteyen, {
    bool showLocal = true,
    bool sendPush = true,
    String? hedefOnaylayici,
  }) async {
    final mesaj = '$servoBizNo cihazı için\n"$istenenDurum" onay bekliyor';

    // Yerel bildirim göster
    if (showLocal) {
      final androidDetails = AndroidNotificationDetails(
        _onayKanalId,
        'Onay Bildirimleri',
        channelDescription: 'Onay isteği bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        colorized: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(mesaj),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _bildirimPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '$isteyen Onay İstedi',
        mesaj,
        notificationDetails,
      );
    }
    
    // Tüm cihazlara (veya belirli onaylayıcıya) push bildirim gönder
    if (sendPush) {
      await _fcmServisi.onayIstegiBildirimi(
        servoBizNo: servoBizNo,
        istenenDurum: istenenDurum,
        isteyen: isteyen,
        hedefOnaylayici: hedefOnaylayici,
      );
    }
  }

  /// Onay isteği sonuçlandı bildirimi
  /// sendPush: Tüm cihazlara push bildirim gönder (varsayılan: true)
  Future<void> onayIstegiSonuclandi(
    String servoBizNo,
    String durum,
    bool onaylandi,
    String islemYapan, {
    bool showLocal = true,
    bool sendPush = true,
    String? hedefKullanici,
  }) async {
    final String baslik = onaylandi ? '$islemYapan Onayladı' : '$islemYapan Reddetti';
    final String mesaj = onaylandi
        ? '$servoBizNo cihazı\n"$durum" olarak güncellendi'
        : '$servoBizNo cihazı için\nonay isteği reddedildi';

    // Yerel bildirim göster
    if (showLocal) {
      final androidDetails = AndroidNotificationDetails(
        _onayKanalId,
        'Onay Bildirimleri',
        channelDescription: 'Onay isteği bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        colorized: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(mesaj),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _bildirimPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        baslik,
        mesaj,
        notificationDetails,
      );
    }
    
    // Onay isteyen kullanıcıya push bildirim gönder
    if (sendPush && hedefKullanici != null) {
      await _fcmServisi.onaySonucuBildirimi(
        servoBizNo: servoBizNo,
        durum: durum,
        onaylandi: onaylandi,
        islemYapan: islemYapan,
        hedefKullanici: hedefKullanici,
      );
    }
  }

  /// Hata bildirimi
  Future<void> hataBildirimi(String hataMesaji) async {
    const androidDetails = AndroidNotificationDetails(
      _genelKanalId,
      'Genel Bildirimler',
      channelDescription: 'Diger bildirimler',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      colorized: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _bildirimPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Hata',
      hataMesaji,
      notificationDetails,
    );
  }
}
