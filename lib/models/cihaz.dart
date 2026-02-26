import 'islem_raporu.dart';

class Cihaz {
  final String servoBizNo;
  final String tarih;
  final String seriNo;
  final String markaModel;
  final String durum; // Giriş / Çıkış
  final String? cihazTuru; // SBZ-SRV, SBZ-VENTILATOR, vb.
  final String? yanilanIslem; // Tamir, Test, vb.
  final String? firmaIsmi;
  final String? notlar;
  final String? kaydedenKullaniciAdi;
  final String? sonGuncelleyen;
  final DateTime? sonDurumDegisiklikTarihi;
  final List<IslemRaporu> islemRaporlari;

  Cihaz({
    required this.servoBizNo,
    required this.tarih,
    required this.seriNo,
    required this.markaModel,
    required this.durum,
    this.cihazTuru,
    this.yanilanIslem,
    this.firmaIsmi,
    this.notlar,
    this.kaydedenKullaniciAdi,
    this.sonGuncelleyen,
    this.sonDurumDegisiklikTarihi,
    List<IslemRaporu>? islemRaporlari,
  }) : islemRaporlari = islemRaporlari ?? [];

  // JSON'a dönüştürme (veritabanı için)
  Map<String, dynamic> toJson() {
    return {
      'servoBizNo': servoBizNo,
      'tarih': tarih,
      'seriNo': seriNo,
      'markaModel': markaModel,
      'durum': durum,
      'cihazTuru': cihazTuru,
      'yanilanIslem': yanilanIslem,
      'firmaIsmi': firmaIsmi,
      'notlar': notlar,
      'kaydedenKullaniciAdi': kaydedenKullaniciAdi,
      'sonGuncelleyen': sonGuncelleyen,
      'sonDurumDegisiklikTarihi': sonDurumDegisiklikTarihi?.toIso8601String(),
      'islemRaporlari': islemRaporlari.map((r) => r.toJson()).toList(),
    };
  }

  // JSON'dan oluşturma (veritabanından)
  factory Cihaz.fromJson(Map<String, dynamic> json) {
    return Cihaz(
      servoBizNo: json['servoBizNo'],
      tarih: json['tarih'],
      seriNo: json['seriNo'],
      markaModel: json['markaModel'],
      durum: json['durum'],
      cihazTuru: json['cihazTuru'],
      yanilanIslem: json['yanilanIslem'],
      firmaIsmi: json['firmaIsmi'],
      notlar: json['notlar'],
      kaydedenKullaniciAdi: json['kaydedenKullaniciAdi'],
      sonGuncelleyen: json['sonGuncelleyen'],
      sonDurumDegisiklikTarihi: json['sonDurumDegisiklikTarihi'] != null 
          ? DateTime.parse(json['sonDurumDegisiklikTarihi']) 
          : null,
      islemRaporlari: json['islemRaporlari'] != null
          ? (json['islemRaporlari'] as List)
              .map((r) => IslemRaporu.fromJson(r))
              .toList()
          : [],
    );
  }

  // Cihaz kopyalama (durum değişikliği için)
  Cihaz copyWith({
    String? servoBizNo,
    String? tarih,
    String? seriNo,
    String? markaModel,
    String? durum,
    String? cihazTuru,
    String? yanilanIslem,
    String? firmaIsmi,
    String? notlar,
    String? kaydedenKullaniciAdi,
    String? sonGuncelleyen,
    DateTime? sonDurumDegisiklikTarihi,
    List<IslemRaporu>? islemRaporlari,
  }) {
    return Cihaz(
      servoBizNo: servoBizNo ?? this.servoBizNo,
      tarih: tarih ?? this.tarih,
      seriNo: seriNo ?? this.seriNo,
      markaModel: markaModel ?? this.markaModel,
      durum: durum ?? this.durum,
      cihazTuru: cihazTuru ?? this.cihazTuru,
      yanilanIslem: yanilanIslem ?? this.yanilanIslem,
      firmaIsmi: firmaIsmi ?? this.firmaIsmi,
      notlar: notlar ?? this.notlar,
      kaydedenKullaniciAdi: kaydedenKullaniciAdi ?? this.kaydedenKullaniciAdi,
      sonGuncelleyen: sonGuncelleyen ?? this.sonGuncelleyen,
      sonDurumDegisiklikTarihi: sonDurumDegisiklikTarihi ?? this.sonDurumDegisiklikTarihi,
      islemRaporlari: islemRaporlari ?? List.from(this.islemRaporlari),
    );
  }
}
