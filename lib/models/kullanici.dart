class Kullanici {
  final String email;
  final String kullaniciAdi;
  String adSoyad;
  String sifre;

  Kullanici({
    required this.email,
    required this.kullaniciAdi,
    required this.adSoyad,
    required this.sifre,
  });

  // JSON'dan Kullanici oluştur
  factory Kullanici.fromJson(Map<String, dynamic> json) {
    return Kullanici(
      email: json['email'] ?? '',
      kullaniciAdi: json['kullaniciAdi'] ?? '',
      adSoyad: json['adSoyad'] ?? '',
      sifre: json['sifre'] ?? '',
    );
  }

  // Kullanici'yi JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'kullaniciAdi': kullaniciAdi,
      'adSoyad': adSoyad,
      'sifre': sifre,
    };
  }

  // Kopyalama metodu
  Kullanici copyWith({
    String? email,
    String? kullaniciAdi,
    String? adSoyad,
    String? sifre,
  }) {
    return Kullanici(
      email: email ?? this.email,
      kullaniciAdi: kullaniciAdi ?? this.kullaniciAdi,
      adSoyad: adSoyad ?? this.adSoyad,
      sifre: sifre ?? this.sifre,
    );
  }

  @override
  String toString() {
    return 'Kullanici{email: $email, kullaniciAdi: $kullaniciAdi, adSoyad: $adSoyad}';
  }
}