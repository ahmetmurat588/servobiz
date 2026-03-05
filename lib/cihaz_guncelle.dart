import 'package:flutter/material.dart';
import 'models/cihaz.dart';
import 'models/onay_istegi.dart';
import 'models/islem_raporu.dart';
import 'services/cihaz_servisi.dart';
import 'services/yetkilendirme_sistemi.dart';
import 'services/kimlik_dogrulama.dart';
import 'services/onay_servisi.dart';
import 'services/bildirim_servisi.dart';

class CihazGuncelleSayfasi extends StatefulWidget {
  final Cihaz? cihaz;

  const CihazGuncelleSayfasi({
    super.key,
    this.cihaz,
  });

  @override
  State<CihazGuncelleSayfasi> createState() => _CihazGuncelleSayfasiState();
}

class _CihazGuncelleSayfasiState extends State<CihazGuncelleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _servoBizNoController = TextEditingController();
  final TextEditingController _tarikhController = TextEditingController();
  final TextEditingController _seriNoController = TextEditingController();
  final TextEditingController _markaModelController = TextEditingController();
  final TextEditingController _firmaController = TextEditingController();
  final TextEditingController _notlarController = TextEditingController();
  final TextEditingController _aramaController = TextEditingController();

  final CihazServisi _cihazServisi = CihazServisi();
  final YetkilendirmeSistemi _yetkiSistemi = YetkilendirmeSistemi();
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();
  final OnayServisi _onayServisi = OnayServisi();
  final BildirimServisi _bildirimServisi = BildirimServisi();

  Cihaz? _secilenCihaz;
  String? _secilenDurum;
  List<String> _izinliDurumlar = [];
  bool _cihazSecildi = false;

  // Admin kontrolü
  bool get _adminMi {
    final aktifKullanici = _auth.aktifoKullanici;
    return aktifKullanici != null && _yetkiSistemi.adminMi(aktifKullanici.email);
  }

  @override
  void initState() {
    super.initState();
    _izinliDurumlariYukle();
    
    if (widget.cihaz != null) {
      _cihazSec(widget.cihaz!);
    }
  }

  void _izinliDurumlariYukle() {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici != null) {
      _izinliDurumlar = _yetkiSistemi.erisilebilenDurumlariAl(kullanici.email);
    }
  }

  void _cihazSec(Cihaz cihaz) {
    setState(() {
      _secilenCihaz = cihaz;
      _cihazSecildi = true;
      _servoBizNoController.text = cihaz.servoBizNo;
      _tarikhController.text = cihaz.tarih;
      _seriNoController.text = cihaz.seriNo;
      _markaModelController.text = cihaz.markaModel;
      _firmaController.text = cihaz.firmaIsmi ?? '';
      _notlarController.text = cihaz.notlar ?? '';
      _secilenDurum = null; // Yeni durum seçilmeli
    });
  }

  void _cihazAra() {
    final arama = _aramaController.text.trim();
    if (arama.isEmpty) {
      _showHata('Lütfen ServoBiz No giriniz');
      return;
    }

    final cihaz = _cihazServisi.cihazBul(arama);
    if (cihaz != null) {
      _cihazSec(cihaz);
    } else {
      _showHata('Cihaz bulunamadı: $arama');
    }
  }

  @override
  void dispose() {
    _servoBizNoController.dispose();
    _tarikhController.dispose();
    _seriNoController.dispose();
    _markaModelController.dispose();
    _firmaController.dispose();
    _notlarController.dispose();
    _aramaController.dispose();
    super.dispose();
  }

  // Seçilen duruma yetkisi var mı?
  bool _yetkiVarMi(String durum) {
    return _izinliDurumlar.contains(durum);
  }

  Future<void> _guncelleCihaz() async {
    if (_secilenCihaz == null) {
      _showHata('Lütfen bir cihaz seçiniz');
      return;
    }

    if (_secilenDurum == null) {
      _showHata('Lütfen bir durum seçiniz');
      return;
    }

    // İşlem Raporu kontrolü - BOŞ OLAMAZ
    if (_notlarController.text.trim().isEmpty) {
      _showHata('Lütfen işlem raporunu doldurunuz');
      return;
    }

    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) {
      _showHata('Lütfen giriş yapınız');
      return;
    }

    // Yetkili durum - doğrudan güncelle
    if (_yetkiVarMi(_secilenDurum!)) {
      // Firma değişti mi kontrol et (admin ise)
      final firmaGuncellendi = _adminMi && 
          _firmaController.text.trim() != (_secilenCihaz!.firmaIsmi ?? '');
      
      if (firmaGuncellendi) {
        // Önce firma bilgisini güncelle
        final guncelCihaz = _secilenCihaz!.copyWith(
          firmaIsmi: _firmaController.text.trim(),
        );
        await _cihazServisi.cihazEkle(guncelCihaz);
      }
      
      final basarili = await _cihazServisi.durumGuncelle(
        _secilenCihaz!.servoBizNo,
        _secilenDurum!,
        notlar: _notlarController.text.trim(),
      );

      if (basarili) {
        // Bildirim gönder
        await _bildirimServisi.cihazDurumuGuncellendi(
          _secilenCihaz!.servoBizNo,
          _secilenCihaz!.durum,
          _secilenDurum!,
          kullanici.adSoyad,
        );
        
        _showSuccess(firmaGuncellendi 
            ? 'Cihaz durumu ve firma bilgisi güncellendi!' 
            : 'Cihaz durumu güncellendi!');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        _showHata('Güncelleme başarısız');
      }
    } else {
      // Yetkisiz durum - onaya gönder
      await _onayaGonder();
    }
  }

  Future<void> _onayaGonder() async {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null || _secilenCihaz == null || _secilenDurum == null) return;

    // Zaten bekleyen istek var mı?
    final mevcutIstek = _onayServisi.cihazIcinBekleyenIstek(_secilenCihaz!.servoBizNo);
    if (mevcutIstek != null) {
      _showHata('Bu cihaz için zaten bekleyen bir onay isteği var');
      return;
    }

    try {
      await _onayServisi.istekOlustur(
        cihazServoBizNo: _secilenCihaz!.servoBizNo,
        mevcutDurum: _secilenCihaz!.durum,
        istenenDurum: _secilenDurum!,
        isteyenEmail: kullanici.email,
        isteyenAd: kullanici.adSoyad,
        not: _notlarController.text.trim(),
      );

      // Bildirim gönder
      await _bildirimServisi.onayIstegiOlusturuldu(
        _secilenCihaz!.servoBizNo,
        _secilenDurum!,
        kullanici.adSoyad,
      );

      _showSuccess('Onay isteği gönderildi! Yetkili onayladığında durum değişecektir.');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      _showHata('Onay isteği gönderilemedi');
    }
  }

  void _showHata(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2E6D),
        elevation: 0,
        title: const Text(
          "CİHAZ DURUMU GÜNCELLE",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Cihaz Arama (sadece cihaz seçilmemişse göster)
                if (!_cihazSecildi) ...[
                  // Cihaz Arama bölümü
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _aramaController,
                          decoration: InputDecoration(
                            labelText: "ServoBiz No ile Ara",
                            labelStyle: const TextStyle(color: Colors.white),
                            hintText: "Örn: SBZ-2025-001",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: const Icon(Icons.search, color: Colors.white),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white, width: 1.5),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          onFieldSubmitted: (_) => _cihazAra(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _cihazAra,
                        child: const Icon(Icons.search, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Yetki bildirimi
                  _buildYetkiBilgisi(),
                  const SizedBox(height: 20),
                  
                  // Onaylayabileceğim istekler
                  _buildOnaylayabilecegimIstekler(),
                  const SizedBox(height: 20),
                  
                  // Gönderdiğim istekler
                  _buildGonderdigimIstekler(),
                ],

                // Cihaz seçildiyse bilgileri göster
                if (_cihazSecildi) ...[
                  // Farklı cihaz ara butonu
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _cihazSecildi = false;
                          _secilenCihaz = null;
                          _secilenDurum = null;
                          _aramaController.clear();
                        });
                      },
                      icon: const Icon(Icons.search, color: Colors.white70),
                      label: const Text('Farklı Cihaz Ara', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // ServoBiz No
                  _buildReadOnlyField(_servoBizNoController, "ServoBiz No", Icons.fingerprint),
                  const SizedBox(height: 20),

                  // Tarih
                  _buildReadOnlyField(_tarikhController, "Tarih", Icons.calendar_today),
                  const SizedBox(height: 20),

                  // Seri No
                  _buildReadOnlyField(_seriNoController, "Seri No", Icons.assignment),
                  const SizedBox(height: 20),

                  // Marka Model
                  _buildReadOnlyField(_markaModelController, "Marka Model", Icons.info),
                  const SizedBox(height: 20),

                  // Firma Bilgisi - Admin düzenleyebilir
                  _buildFirmaField(),
                  const SizedBox(height: 20),

                  // Mevcut Durum (bilgi)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white70),
                        const SizedBox(width: 10),
                        Text(
                          'Mevcut Durum: ${_secilenCihaz?.durum ?? "-"}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Yeni Durum Seçimi - Tüm durumlar
                  _buildDurumSecimi(),
                  const SizedBox(height: 20),

                  // İşlem Raporu (ZORUNLU)
                  TextFormField(
                    controller: _notlarController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "İşlem Raporu *",
                      labelStyle: const TextStyle(color: Colors.white),
                      hintText: "İşlem ile ilgili rapor ekleyiniz (zorunlu)",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.receipt, color: Colors.white),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'İşlem raporu zorunludur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // Güncelle / Onaya Gönder Butonu
                  _buildActionButton(),
                  const SizedBox(height: 20),

                  // İptal Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "İPTAL",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  // Kayıtlı İşlem Raporları
                  if (_secilenCihaz != null && _secilenCihaz!.islemRaporlari.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    _buildIslemRaporlari(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYetkiBilgisi() {
    if (_izinliDurumlar.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: const Column(
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Doğrudan durum değiştirme yetkiniz bulunmuyor.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Tüm durumlar için onay isteği gönderebilirsiniz. Yetkili kişi onayladığında durum değişecektir.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text(
                'Doğrudan değiştirebileceğiniz durumlar:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _izinliDurumlar.map((durum) {
              return Chip(
                label: Text(durum, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.green.withOpacity(0.5),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Diğer durumlar için onay isteği gönderebilirsiniz.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDurumSecimi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yeni Durum Seçin:',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...YetkilendirmeSistemi.tumDurumlar.map((durum) {
          final yetkili = _yetkiVarMi(durum);
          final secili = _secilenDurum == durum;
          final mevcutDurum = durum == _secilenCihaz?.durum;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: mevcutDurum ? null : () {
                setState(() {
                  _secilenDurum = durum;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: secili 
                      ? (yetkili ? Colors.green.withOpacity(0.4) : Colors.orange.withOpacity(0.4))
                      : Colors.white.withOpacity(mevcutDurum ? 0.05 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: secili 
                        ? (yetkili ? Colors.green : Colors.orange)
                        : Colors.white.withOpacity(0.3),
                    width: secili ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Durum ikonu
                    Icon(
                      secili 
                          ? Icons.radio_button_checked 
                          : Icons.radio_button_unchecked,
                      color: mevcutDurum 
                          ? Colors.white38 
                          : (secili 
                              ? (yetkili ? Colors.green : Colors.orange) 
                              : Colors.white70),
                    ),
                    const SizedBox(width: 12),
                    // Durum adı
                    Expanded(
                      child: Text(
                        durum,
                        style: TextStyle(
                          color: mevcutDurum ? Colors.white38 : Colors.white,
                          fontSize: 16,
                          fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    // Yetki durumu
                    if (mevcutDurum)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Mevcut',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      )
                    else if (yetkili)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Yetkili',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Onay Gerekli',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_secilenDurum == null) {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: null,
          child: const Text(
            "DURUM SEÇİNİZ",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final yetkili = _yetkiVarMi(_secilenDurum!);

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: yetkili 
              ? const Color.fromARGB(255, 16, 144, 255) 
              : Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
        ),
        onPressed: _guncelleCihaz,
        icon: Icon(
          yetkili ? Icons.check_circle : Icons.send,
          color: Colors.white,
        ),
        label: Text(
          yetkili ? "GÜNCELLE" : "ONAYA GÖNDER",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
        ),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );
  }

  // Firma alanı - Admin için düzenlenebilir
  Widget _buildFirmaField() {
    return TextFormField(
      controller: _firmaController,
      readOnly: !_adminMi,
      decoration: InputDecoration(
        labelText: _adminMi ? "Firma İsmi (Düzenlenebilir)" : "Firma İsmi",
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(Icons.business, color: _adminMi ? Colors.amber : Colors.white),
        suffixIcon: _adminMi 
            ? Icon(Icons.edit, color: Colors.amber, size: 20) 
            : null,
        filled: true,
        fillColor: _adminMi 
            ? Colors.amber.withOpacity(0.15) 
            : Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _adminMi ? Colors.amber : Colors.white, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _adminMi ? Colors.amber : Colors.white.withOpacity(0.5), 
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _adminMi ? Colors.amber : Colors.white, width: 2),
        ),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );
  }

  Widget _buildOnaylayabilecegimIstekler() {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return const SizedBox.shrink();

    final istekler = _onayServisi.onaylayabilecekIstekler(kullanici.email);
    if (istekler.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.approval, color: Colors.green),
              const SizedBox(width: 10),
              Text(
                'Onayınızı Bekleyen İstekler (${istekler.length})',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...istekler.map((istek) => _buildOnayIstegiKarti(istek, onaylayabilir: true)),
        ],
      ),
    );
  }

  Widget _buildGonderdigimIstekler() {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return const SizedBox.shrink();

    final istekler = _onayServisi.kullanicininIstekleri(kullanici.email)
        .where((i) => i.durum == OnayDurumu.beklemede)
        .toList();
    if (istekler.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.send, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                'Gönderdiğim İstekler (${istekler.length})',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...istekler.map((istek) => _buildOnayIstegiKarti(istek, onaylayabilir: false)),
        ],
      ),
    );
  }

  Widget _buildOnayIstegiKarti(OnayIstegi istek, {required bool onaylayabilir}) {
    final cihaz = _cihazServisi.cihazBul(istek.cihazServoBizNo);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cihaz bilgisi
          Row(
            children: [
              const Icon(Icons.devices, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  istek.cihazServoBizNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (cihaz != null)
                Text(
                  cihaz.markaModel,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Durum değişikliği
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  istek.mevcutDurum,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  istek.istenenDurum,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          
          // İsteyen ve tarih
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(
                istek.isteyenAd,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.access_time, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(
                _formatTarih(istek.istekTarihi),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          
          // Not varsa göster
          if (istek.not != null && istek.not!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                istek.not!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
          
          // Onaylayabilir ise butonlar göster
          if (onaylayabilir) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _onaylaIstek(istek),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('Onayla', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _reddetIstek(istek),
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    label: const Text('Reddet', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Kendi isteği ise iptal butonu
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _iptalEtIstek(istek),
                icon: const Icon(Icons.cancel, color: Colors.orange, size: 18),
                label: const Text('İptal Et', style: TextStyle(color: Colors.orange)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTarih(DateTime tarih) {
    return '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year} ${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _onaylaIstek(OnayIstegi istek) async {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return;

    final basarili = await _onayServisi.onayla(istek.id, kullanici.email);
    if (basarili) {
      _showSuccess('İstek onaylandı! Cihaz durumu güncellendi.');
      setState(() {});
    } else {
      _showHata('Onaylama başarısız');
    }
  }

  Future<void> _reddetIstek(OnayIstegi istek) async {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return;

    final basarili = await _onayServisi.reddet(istek.id, kullanici.email);
    if (basarili) {
      _showSuccess('İstek reddedildi.');
      setState(() {});
    } else {
      _showHata('Reddetme başarısız');
    }
  }

  Future<void> _iptalEtIstek(OnayIstegi istek) async {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return;

    final basarili = await _onayServisi.iptalEt(istek.id, kullanici.email);
    if (basarili) {
      _showSuccess('İstek iptal edildi.');
      setState(() {});
    } else {
      _showHata('İptal etme başarısız');
    }
  }

  /// Kayıtlı işlem raporlarını göster
  Widget _buildIslemRaporlari() {
    final raporlar = _secilenCihaz?.islemRaporlari ?? [];
    if (raporlar.isEmpty) {
      return const SizedBox.shrink();
    }

    // En yeniden en eskiye sırala
    final siraliRaporlar = List<IslemRaporu>.from(raporlar)
      ..sort((a, b) => b.tarih.compareTo(a.tarih));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.history, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Kayıtlı İşlem Raporları (${siraliRaporlar.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Raporlar listesi
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: siraliRaporlar.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.white.withOpacity(0.2),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final rapor = siraliRaporlar[index];
              return _buildRaporKarti(rapor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRaporKarti(IslemRaporu rapor) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı - Yazan ve tarih
          Row(
            children: [
              // Kullanıcı ikonu ve adı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      rapor.yazanKullanici,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Tarih
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatTarih(rapor.tarih),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Durum değişikliği
          if (rapor.eskiDurum != null && rapor.yeniDurum != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${rapor.eskiDurum} → ${rapor.yeniDurum}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Rapor içeriği
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rapor.icerik,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}