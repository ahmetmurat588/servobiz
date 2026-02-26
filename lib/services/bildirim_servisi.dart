import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BildirimServisi {
  static final BildirimServisi _instance = BildirimServisi._internal();
  factory BildirimServisi() => _instance;
  BildirimServisi._internal();

  final FlutterLocalNotificationsPlugin _bildirimPlugin = 
      FlutterLocalNotificationsPlugin();

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
  Future<void> cihazKaydedildi(String servoBizNo, String markaModel, {String? kaydeden}) async {
    final mesaj = kaydeden != null 
        ? '$kaydeden yeni cihaz kaydetti:\n$servoBizNo - $markaModel'
        : 'ServoBiz No: $servoBizNo\n$markaModel';

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

  /// Cihaz durumu güncellendi bildirimi
  Future<void> cihazDurumuGuncellendi(
    String servoBizNo,
    String eskiDurum,
    String yeniDurum,
    String guncelleyen,
  ) async {
    final mesaj = '$servoBizNo\n$eskiDurum → $yeniDurum';

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

  /// Onay isteği oluşturuldu bildirimi
  Future<void> onayIstegiOlusturuldu(
    String servoBizNo,
    String istenenDurum,
    String isteyen,
  ) async {
    final mesaj = '$servoBizNo cihazı için\n"$istenenDurum" onay bekliyor';

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

  /// Onay isteği sonuçlandı bildirimi
  Future<void> onayIstegiSonuclandi(
    String servoBizNo,
    String durum,
    bool onaylandi,
    String islemYapan,
  ) async {
    final String baslik = onaylandi ? '$islemYapan Onayladı' : '$islemYapan Reddetti';
    final String mesaj = onaylandi
        ? '$servoBizNo cihazı\n"$durum" olarak güncellendi'
        : '$servoBizNo cihazı için\nonay isteği reddedildi';

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
