import 'package:flutter/material.dart';
import 'services/kimlik_dogrulama.dart';
import 'services/yetkilendirme_sistemi.dart';


class YetkilendirmeSayfasi extends StatefulWidget {
  const YetkilendirmeSayfasi({super.key});

  @override
  State<YetkilendirmeSayfasi> createState() => _YetkilendirmeSayfasiState();
}

class _YetkilendirmeSayfasiState extends State<YetkilendirmeSayfasi> {
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();
  final YetkilendirmeSistemi _yetkiSistemi = YetkilendirmeSistemi();
  final TextEditingController _yeniKullaniciController = TextEditingController();

  String? _secilenKullanici;
  List<String> _secilenDurumlar = <String>[];

  @override
  void dispose() {
    _yeniKullaniciController.dispose();
    super.dispose();
  }

  void _kullaniciSec(String email) {
    setState(() {
      _secilenKullanici = email;
      _secilenDurumlar = _yetkiSistemi.erisilebilenDurumlariAl(email);
    });
  }

  void _durumToggle(String durum) {
    setState(() {
      if (_secilenDurumlar.contains(durum)) {
        _secilenDurumlar.remove(durum);
      } else {
        _secilenDurumlar.add(durum);
      }
    });
  }

  Future<void> _yetkiKaydet() async {
    if (_secilenKullanici == null) {
      _showError('Lütfen bir kullanıcı seçin.');
      return;
    }

    final aktifKullanici = _auth.aktifoKullanici;
    if (aktifKullanici == null) return;

    final basarili = await _yetkiSistemi.yetkiGuncelle(
      aktifKullanici.email,
      _secilenKullanici!,
      _secilenDurumlar,
    );

    if (basarili) {
      _showSuccess('Yetkiler başarıyla kaydedildi.');
    } else {
      _showError('Yetkiler kaydedilemedi. Admin yetkisi gerekli.');
    }
  }

  Future<void> _kullaniciYetkisiKaldir(String kullaniciEmail) async {
    final aktifKullanici = _auth.aktifoKullanici;
    if (aktifKullanici == null) return;

    final basarili = await _yetkiSistemi.yetkiKaldir(
      aktifKullanici.email,
      kullaniciEmail,
    );

    if (basarili) {
      _showSuccess('Kullanıcı yetkileri kaldırıldı.');
      setState(() {
        if (_secilenKullanici == kullaniciEmail) {
          _secilenKullanici = null;
          _secilenDurumlar = <String>[];
        }
      });
    } else {
      _showError('Yetkiler kaldırılamadı.');
    }
  }

  Future<void> _tekYetkiKaldir(String kullaniciEmail, String durum) async {
    final aktifKullanici = _auth.aktifoKullanici;
    if (aktifKullanici == null) return;

    final basarili = await _yetkiSistemi.tekYetkiKaldir(
      aktifKullanici.email,
      kullaniciEmail,
      durum,
    );

    if (basarili) {
      _showSuccess('$durum yetkisi kaldırıldı.');
      setState(() {});
    } else {
      _showError('Yetki kaldırılamadı.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aktifKullanici = _auth.aktifoKullanici;
    final adminMi = aktifKullanici != null && _yetkiSistemi.adminMi(aktifKullanici.email);

    if (!adminMi) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F2E6D),
          elevation: 0,
          title: const Text(
            "YETKİLENDİRME",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 0, 0, 0)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A3C8B), Color(0xFF5F87D6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 80, color: Colors.white.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'Bu sayfaya erişim yetkiniz yok.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sadece admin kullanıcılar bu sayfayı görebilir.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2E6D),
        elevation: 0,
        title: const Text(
          "YETKİLENDİRME",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 255, 255, 255)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A3C8B), Color(0xFF5F87D6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kullanıcı Seçimi
              _buildKullaniciSecimi(),
              const SizedBox(height: 20),

              // Seçili kullanıcı için yetki düzenleme
              if (_secilenKullanici != null) ...[
                _buildYetkiDuzenleme(),
                const SizedBox(height: 20),
              ],

              // Mevcut yetkiler listesi
              _buildMevcutYetkiler(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKullaniciSecimi() {
    final kullanicilar = _auth.tumKullanicilar;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kullanıcı Seçin',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (kullanicilar.isEmpty)
            Text(
              'Kayıtlı kullanıcı bulunmuyor.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kullanicilar.map((kullanici) {
                final secili = _secilenKullanici == kullanici.email;
                final adminMi = _yetkiSistemi.adminMi(kullanici.email);
                return InkWell(
                  onTap: () => _kullaniciSec(kullanici.email),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: secili ? Colors.blue.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: secili ? Colors.blue : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          adminMi ? Icons.admin_panel_settings : Icons.person,
                          color: adminMi ? Colors.amber : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          kullanici.kullaniciAdi,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildYetkiDuzenleme() {
    final adminMi = _yetkiSistemi.adminMi(_secilenKullanici!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Yetki Düzenle',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (adminMi)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text('Admin', style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _secilenKullanici!,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 16),

          if (adminMi)
            Text(
              'Admin kullanıcının yetkileri değiştirilemez.',
              style: TextStyle(color: Colors.orange.withOpacity(0.8)),
            )
          else ...[
            const Text(
              'Erişebileceği Durumlar:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: YetkilendirmeSistemi.tumDurumlar.map((durum) {
                final secili = _secilenDurumlar.contains(durum);
                return FilterChip(
                  label: Text(
                    durum,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                  selected: secili,
                  onSelected: (_) => _durumToggle(durum),
                  backgroundColor: Colors.transparent,
                  selectedColor: Colors.green.withOpacity(0.5),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: secili ? Colors.green : Colors.white.withOpacity(0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _yetkiKaydet,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _kullaniciYetkisiKaldir(_secilenKullanici!),
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Tüm Yetkileri Kaldır', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMevcutYetkiler() {
    final aktifKullanici = _auth.aktifoKullanici;
    if (aktifKullanici == null) return const SizedBox.shrink();

    final tumYetkiler = _yetkiSistemi.tumYetkileriAl(aktifKullanici.email);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mevcut Yetkiler',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (tumYetkiler.isEmpty)
            Text(
              'Henüz yetki tanımlanmamış.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            )
          else
            ...tumYetkiler.entries.map((entry) {
              final email = entry.key;
              final yetki = entry.value;
              final kullanici = _auth.tumKullanicilar.where((k) => k.email == email).firstOrNull;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          yetki.adminMi ? Icons.admin_panel_settings : Icons.person,
                          color: yetki.adminMi ? Colors.amber : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          kullanici?.kullaniciAdi ?? email,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (yetki.adminMi) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(color: Colors.amber, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: yetki.erisilebilenDurumlar.map((durum) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                durum,
                                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 11),
                              ),
                              if (!yetki.adminMi) ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _tekYetkiKaldir(email, durum),
                                  child: const Icon(Icons.close, color: Colors.white70, size: 14),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
