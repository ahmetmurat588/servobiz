/// Onay İsteği Modeli
/// Yetkisiz durum değişiklikleri için onay isteği
class OnayIstegi {
  final String id;
  final String cihazServoBizNo;
  final String mevcutDurum;
  final String istenenDurum;
  final String isteyenEmail;
  final String isteyenAd;
  final DateTime istekTarihi;
  final String? not;
  final OnayDurumu durum;
  final String? onaylayanEmail;
  final DateTime? onayTarihi;

  OnayIstegi({
    required this.id,
    required this.cihazServoBizNo,
    required this.mevcutDurum,
    required this.istenenDurum,
    required this.isteyenEmail,
    required this.isteyenAd,
    required this.istekTarihi,
    this.not,
    this.durum = OnayDurumu.beklemede,
    this.onaylayanEmail,
    this.onayTarihi,
  });

  OnayIstegi copyWith({
    String? id,
    String? cihazServoBizNo,
    String? mevcutDurum,
    String? istenenDurum,
    String? isteyenEmail,
    String? isteyenAd,
    DateTime? istekTarihi,
    String? not,
    OnayDurumu? durum,
    String? onaylayanEmail,
    DateTime? onayTarihi,
  }) {
    return OnayIstegi(
      id: id ?? this.id,
      cihazServoBizNo: cihazServoBizNo ?? this.cihazServoBizNo,
      mevcutDurum: mevcutDurum ?? this.mevcutDurum,
      istenenDurum: istenenDurum ?? this.istenenDurum,
      isteyenEmail: isteyenEmail ?? this.isteyenEmail,
      isteyenAd: isteyenAd ?? this.isteyenAd,
      istekTarihi: istekTarihi ?? this.istekTarihi,
      not: not ?? this.not,
      durum: durum ?? this.durum,
      onaylayanEmail: onaylayanEmail ?? this.onaylayanEmail,
      onayTarihi: onayTarihi ?? this.onayTarihi,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cihazServoBizNo': cihazServoBizNo,
      'mevcutDurum': mevcutDurum,
      'istenenDurum': istenenDurum,
      'isteyenEmail': isteyenEmail,
      'isteyenAd': isteyenAd,
      'istekTarihi': istekTarihi.toIso8601String(),
      'not': not,
      'durum': durum.name,
      'onaylayanEmail': onaylayanEmail,
      'onayTarihi': onayTarihi?.toIso8601String(),
    };
  }

  factory OnayIstegi.fromJson(Map<String, dynamic> json) {
    return OnayIstegi(
      id: json['id'],
      cihazServoBizNo: json['cihazServoBizNo'],
      mevcutDurum: json['mevcutDurum'],
      istenenDurum: json['istenenDurum'],
      isteyenEmail: json['isteyenEmail'],
      isteyenAd: json['isteyenAd'],
      istekTarihi: DateTime.parse(json['istekTarihi']),
      not: json['not'],
      durum: OnayDurumu.values.firstWhere(
        (e) => e.name == json['durum'],
        orElse: () => OnayDurumu.beklemede,
      ),
      onaylayanEmail: json['onaylayanEmail'],
      onayTarihi: json['onayTarihi'] != null ? DateTime.parse(json['onayTarihi']) : null,
    );
  }
}

enum OnayDurumu {
  beklemede,
  onaylandi,
  reddedildi,
}
