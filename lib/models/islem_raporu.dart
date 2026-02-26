/// İşlem Raporu Modeli
/// Her cihaz güncelleme işleminde eklenen rapor
class IslemRaporu {
  final String id;
  final String icerik;
  final String yazanKullanici;
  final String yazanEmail;
  final DateTime tarih;
  final String? eskiDurum;
  final String? yeniDurum;

  IslemRaporu({
    required this.id,
    required this.icerik,
    required this.yazanKullanici,
    required this.yazanEmail,
    required this.tarih,
    this.eskiDurum,
    this.yeniDurum,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'icerik': icerik,
      'yazanKullanici': yazanKullanici,
      'yazanEmail': yazanEmail,
      'tarih': tarih.toIso8601String(),
      'eskiDurum': eskiDurum,
      'yeniDurum': yeniDurum,
    };
  }

  factory IslemRaporu.fromJson(Map<String, dynamic> json) {
    return IslemRaporu(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      icerik: json['icerik'] ?? '',
      yazanKullanici: json['yazanKullanici'] ?? '',
      yazanEmail: json['yazanEmail'] ?? '',
      tarih: json['tarih'] != null 
          ? DateTime.parse(json['tarih']) 
          : DateTime.now(),
      eskiDurum: json['eskiDurum'],
      yeniDurum: json['yeniDurum'],
    );
  }
}
