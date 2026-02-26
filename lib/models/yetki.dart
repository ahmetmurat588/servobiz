/// Kullanıcı yetki profili - Erişilebilir durumlar listesi
class KullaniciYetkisi {
  final String kullaniciEmail;
  final List<String> _erisilebilenDurumlar; // Kullanıcının erişebildiği durumlar
  final bool adminMi; // Yetkilendirme değiştirebilir mi?

  KullaniciYetkisi({
    required this.kullaniciEmail,
    List<String>? erisilebilenDurumlar,
    this.adminMi = false,
  }) : _erisilebilenDurumlar = erisilebilenDurumlar ?? <String>[];

  // Getter - her zaman non-null liste döner
  List<String> get erisilebilenDurumlar => List<String>.from(_erisilebilenDurumlar);

  /// Belirli bir duruma erişim yetkisi var mı?
  bool durumErisimYetkisiVarMi(String durum) {
    return _erisilebilenDurumlar.contains(durum);
  }

  KullaniciYetkisi copyWith({
    String? kullaniciEmail,
    List<String>? erisilebilenDurumlar,
    bool? adminMi,
  }) {
    return KullaniciYetkisi(
      kullaniciEmail: kullaniciEmail ?? this.kullaniciEmail,
      erisilebilenDurumlar: erisilebilenDurumlar ?? List<String>.from(_erisilebilenDurumlar),
      adminMi: adminMi ?? this.adminMi,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kullaniciEmail': kullaniciEmail,
      'erisilebilenDurumlar': _erisilebilenDurumlar,
      'adminMi': adminMi,
    };
  }

  factory KullaniciYetkisi.fromMap(Map<String, dynamic> map) {
    return KullaniciYetkisi(
      kullaniciEmail: map['kullaniciEmail'] ?? '',
      erisilebilenDurumlar: List<String>.from(map['erisilebilenDurumlar'] ?? <String>[]),
      adminMi: map['adminMi'] ?? false,
    );
  }

  // JSON serialization için alias'lar
  Map<String, dynamic> toJson() => toMap();
  factory KullaniciYetkisi.fromJson(Map<String, dynamic> json) => KullaniciYetkisi.fromMap(json);
}

/// Onay bekleyen durum değişikliği
class OnayBekleyenIslem {
  final String id;
  final String cihazServoBizNo;
  final String kaynakDurum;
  final String hedefDurum;
  final String talepEdenEmail;
  final String onaylayanEmail;
  final DateTime talepTarihi;
  bool onaylandi;
  bool reddedildi;

  OnayBekleyenIslem({
    required this.id,
    required this.cihazServoBizNo,
    required this.kaynakDurum,
    required this.hedefDurum,
    required this.talepEdenEmail,
    required this.onaylayanEmail,
    required this.talepTarihi,
    this.onaylandi = false,
    this.reddedildi = false,
  });
}
