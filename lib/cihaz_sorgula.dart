import 'package:flutter/material.dart';
import 'models/cihaz.dart';
import 'services/cihaz_servisi.dart';
import 'services/kimlik_dogrulama.dart';
import 'services/yetkilendirme_sistemi.dart';
import 'services/excel_export_servisi.dart';
import 'cihaz_guncelle.dart';

class CihazSorgulaSayfasi extends StatefulWidget {
  const CihazSorgulaSayfasi({super.key});

  @override
  State<CihazSorgulaSayfasi> createState() => _CihazSorgulaSayfasiState();
}

class _CihazSorgulaSayfasiState extends State<CihazSorgulaSayfasi> {
  final TextEditingController _aramaController = TextEditingController();
  final CihazServisi _cihazServisi = CihazServisi();
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();
  final YetkilendirmeSistemi _yetkiSistemi = YetkilendirmeSistemi();
  final ScrollController _scrollController = ScrollController();
  
  List<Cihaz> _filtrelenmisCihazlar = [];
  String _seciliFiltre = 'Tümü';
  bool _aramaYapildi = false;
  
  // Geri alma için son silinen cihaz
  Cihaz? _sonSilinenCihaz;
  
  // Genişletilmiş kartları takip et
  Set<String> _genisletilmisKartlar = {};

  // ...existing code...

  @override
  void initState() {
    super.initState();
    // Başlangıçta tüm cihazları göster
    _verileriYukle();
    
    // Arama kutusu dinleyicisi - canlı arama için
    _aramaController.addListener(_canliArama);
    
    // Sayfa açıldığında en alta scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollEnAltaGit();
    });
  }
  
  void _scrollEnAltaGit() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _verileriYukle() async {
    // Önce Firestore'dan güncel verileri çek
    await _cihazServisi.init();
    if (mounted) {
      setState(() {
        _filtrelenmisCihazlar = _cihazServisi.cihazlar;
      });
      // Veriler yüklenince en alta scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollEnAltaGit();
      });
    }
  }

  @override
  void dispose() {
    _aramaController.removeListener(_canliArama);
    _aramaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Canlı arama - her harf değişiminde çalışır
  void _canliArama() {
    if (_aramaController.text.isEmpty) {
      // Arama kutusu boşsa tüm cihazları göster
      setState(() {
        _filtrelenmisCihazlar = _cihazServisi.cihazlar;
        _aramaYapildi = false;
      });
    } else {
      _aramaYap(_aramaController.text);
    }
  }

  // Arama butonuna basıldığında
  void _aramaButonu() {
    if (_aramaController.text.isEmpty) {
      // Arama kutusu boşsa tüm cihazları göster
      setState(() {
        _filtrelenmisCihazlar = _cihazServisi.cihazlar;
        _aramaYapildi = false;
      });
      return;
    }
    _aramaYap(_aramaController.text);
  }

  // Arama işlemi
  void _aramaYap(String aramaTerimi) {
    final arama = aramaTerimi.toLowerCase().trim();
    
    setState(() {
      _filtrelenmisCihazlar = _cihazServisi.cihazlar.where((cihaz) {
        switch (_seciliFiltre) {
          case 'ServoBiz No':
            return cihaz.servoBizNo.toLowerCase().contains(arama);
          case 'Seri No':
            return cihaz.seriNo.toLowerCase().contains(arama);
          case 'Marka Model':
            return cihaz.markaModel.toLowerCase().contains(arama);
          case 'Firma İsmi':
            return (cihaz.firmaIsmi ?? '').toLowerCase().contains(arama);
          case 'Durum':
            return cihaz.durum.toLowerCase().contains(arama);
          case 'Tümü':
          default:
            return cihaz.servoBizNo.toLowerCase().contains(arama) ||
                cihaz.seriNo.toLowerCase().contains(arama) ||
                cihaz.markaModel.toLowerCase().contains(arama) ||
                (cihaz.firmaIsmi ?? '').toLowerCase().contains(arama) ||
                cihaz.durum.toLowerCase().contains(arama);
        }
      }).toList();
      
      _aramaYapildi = arama.isNotEmpty;
    });
  }

  // Arama temizle
  void _aramayiTemizle() {
    _aramaController.clear();
    setState(() {
      _filtrelenmisCihazlar = _cihazServisi.cihazlar;
      _aramaYapildi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2E6D),
        elevation: 0,
        title: const Text(
          "CİHAZ SORGULA",
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
        actions: [
          if (_adminMi)
            IconButton(
              icon: const Icon(Icons.table_chart, color: Colors.white),
              tooltip: 'Excel Olarak Dışa Aktar',
              onPressed: _excelExport,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yenile',
            onPressed: _verileriYukle,
          ),
        ],
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
        child: Column(
          children: [
            // Arama Kutusu ve Filtreler
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Arama Kutusu - DÜZELTİLDİ
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent, // Şeffaf yapıldı
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aramaController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "Ara...",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: const Icon(Icons.search, color: Colors.white),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                              // Arka planı tamamen şeffaf yap
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            onSubmitted: (_) => _aramaButonu(),
                          ),
                        ),
                        if (_aramaController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: _aramayiTemizle,
                          ),
                        Container(
                          margin: const EdgeInsets.all(4),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 16, 144, 255),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: _aramaButonu,
                            child: const Text(
                              "ARA",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sonuçlar - Tüm cihazlar her zaman görünür
            Expanded(
              child: _filtrelenmisCihazlar.isEmpty
                  ? _bosDurumMesaji()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _filtrelenmisCihazlar.length,
                      itemBuilder: (context, index) {
                        final cihaz = _filtrelenmisCihazlar[index];
                        return _cihazKarti(cihaz);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Boş durum mesajı
  Widget _bosDurumMesaji() {
    if (_cihazServisi.cihazlar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Henüz kayıtlı cihaz bulunmuyor.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_filtrelenmisCihazlar.isEmpty && _aramaYapildi) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Aramanızla eşleşen cihaz bulunamadı.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Farklı bir arama terimi deneyin.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Admin mi kontrolü
  bool get _adminMi {
    final aktifKullanici = _auth.aktifoKullanici;
    return aktifKullanici != null && _yetkiSistemi.adminMi(aktifKullanici.email);
  }

  // Excel export (sadece admin)
  Future<void> _excelExport() async {
    try {
      final servis = ExcelExportServisi();
      await servis.cihazlariExcelExport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel dosyası oluşturuldu! İndirilenler klasörüne kaydedildi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel export başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Firma bilgisi düzenleme dialogu (sadece admin)
  Future<void> _firmaDuzenleDialog(Cihaz cihaz) async {
    if (!_adminMi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sadece admin kullanıcılar firma bilgilerini düzenleyebilir'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final firmaController = TextEditingController(text: cihaz.firmaIsmi ?? '');
    
    final yeniFirma = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.business, color: Color(0xFF0F2E6D)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Firma Bilgisi Düzenle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2E6D)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cihaz: ${cihaz.servoBizNo}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            SizedBox(height: 16),
            TextField(
              controller: firmaController,
              decoration: InputDecoration(
                labelText: 'Firma İsmi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(Icons.business),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0F2E6D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, firmaController.text.trim()),
            child: Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (yeniFirma != null) {
      // Cihazı güncelle (yenisini ekle)
      final guncelCihaz = cihaz.copyWith(firmaIsmi: yeniFirma);
      await _cihazServisi.cihazEkle(guncelCihaz);
      _verileriYukle();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firma bilgisi güncellendi'), backgroundColor: Colors.green),
      );
    }
  }

  // Admin menüsü göster (uzun basınca)
  void _adminMenuGoster(Cihaz cihaz) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              cihaz.servoBizNo,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2E6D)),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.business, color: Colors.amber.shade700),
              title: Text('Firma Bilgisi Düzenle'),
              onTap: () {
                Navigator.pop(context);
                _firmaDuzenleDialog(cihaz);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Cihazı Sil', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _cihazSilDialog(cihaz);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Cihaz silme dialogu (sadece admin)
  Future<void> _cihazSilDialog(Cihaz cihaz) async {
    if (!_adminMi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sadece admin kullanıcılar cihaz silebilir'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cihazı Sil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu cihazı silmek istediğinizden emin misiniz?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ServoBiz No: ${cihaz.servoBizNo}', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Marka/Model: ${cihaz.markaModel}'),
                  Text('Seri No: ${cihaz.seriNo}'),
                  if (cihaz.firmaIsmi != null && cihaz.firmaIsmi!.isNotEmpty)
                    Text('Firma: ${cihaz.firmaIsmi}'),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silme işlemi sonrası "Geri Al" seçeneği ile cihazı kurtarabilirsiniz.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (onay == true) {
      await _cihazSil(cihaz);
    }
  }

  // Cihaz silme işlemi
  Future<void> _cihazSil(Cihaz cihaz) async {
    // Önce cihazı sakla (geri alma için)
    _sonSilinenCihaz = cihaz;
    
    // Cihazı sil (Firebase + listeden çıkar)
    final basarili = await _cihazServisi.cihazSil(cihaz.servoBizNo);
    if (!basarili) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cihaz silinirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _verileriYukle();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${cihaz.servoBizNo} silindi'),
        backgroundColor: Colors.orange.shade700,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'GERİ AL',
          textColor: Colors.white,
          onPressed: () => _silmeGeriAl(),
        ),
      ),
    );
  }

  // Silme işlemini geri al
  Future<void> _silmeGeriAl() async {
    if (_sonSilinenCihaz == null) return;
    await _cihazServisi.cihazEkle(_sonSilinenCihaz!);
    _verileriYukle();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_sonSilinenCihaz!.servoBizNo} geri yüklendi'),
        backgroundColor: Colors.green,
      ),
    );
    
    _sonSilinenCihaz = null;
  }

  // CİHAZ KARTI TASARIMI - Genişletilebilir
Widget _cihazKarti(Cihaz cihaz) {
  final isExpanded = _genisletilmisKartlar.contains(cihaz.servoBizNo);
  
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        // Ana kart - Her zaman görünür (ServoBiz No, Marka/Model, Durum)
        InkWell(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(12),
            bottom: isExpanded ? Radius.zero : Radius.circular(12),
          ),
          onTap: () async {
            // Cihaz güncelleme sayfasına git
            final sonuc = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CihazGuncelleSayfasi(cihaz: cihaz),
              ),
            );
            if (sonuc == true) {
              _verileriYukle();
            }
          },
          onLongPress: _adminMi ? () => _adminMenuGoster(cihaz) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ServoBiz No ve Durum + Admin Sil butonu
                Row(
                  children: [
                    // ServoBiz No
                    Text(
                      cihaz.servoBizNo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F2E6D),
                      ),
                    ),
                    const Spacer(),
                    // Admin sil butonu
                    if (_adminMi)
                      InkWell(
                        onTap: () => _cihazSilDialog(cihaz),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Durum badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDurumRengi(cihaz.durum).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getDurumRengi(cihaz.durum),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cihaz.durum,
                        style: TextStyle(
                          color: _getDurumRengi(cihaz.durum),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Marka Model
                Row(
                  children: [
                    const Icon(Icons.devices, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cihaz.markaModel,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Genişlet/daralt butonu
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _genisletilmisKartlar.remove(cihaz.servoBizNo);
              } else {
                _genisletilmisKartlar.add(cihaz.servoBizNo);
              }
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: isExpanded 
                  ? BorderRadius.zero 
                  : BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
        ),
        
        // Genişletilmiş detay alanı
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seri No
                _detayRow(Icons.assignment, "Seri No", cihaz.seriNo),
                const SizedBox(height: 6),
                // Firma
                Row(
                  children: [
                    Expanded(child: _detayRow(Icons.business, "Firma", cihaz.firmaIsmi ?? '-')),
                    if (_adminMi)
                      InkWell(
                        onTap: () => _firmaDuzenleDialog(cihaz),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.edit, size: 14, color: Colors.amber.shade700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Tarih
                _detayRow(Icons.calendar_today, "Geliş Tarihi", cihaz.tarih),
                // Kaydeden
                if (cihaz.kaydedenKullaniciAdi != null && cihaz.kaydedenKullaniciAdi!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detayRow(Icons.person, "Kaydeden", cihaz.kaydedenKullaniciAdi!),
                ],
                // Son Güncelleyen
                if (cihaz.sonGuncelleyen != null && cihaz.sonGuncelleyen!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detayRow(Icons.update, "Son Güncelleyen", cihaz.sonGuncelleyen!),
                ],
                // Son Güncelleme Tarihi
                if (cihaz.sonDurumDegisiklikTarihi != null) ...[
                  const SizedBox(height: 6),
                  _detayRow(Icons.access_time, "Son Güncelleme", _formatTarih(cihaz.sonDurumDegisiklikTarihi!)),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

// Detay satırı helper
Widget _detayRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Text(
        "$label: ",
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

// Tarih formatlama fonksiyonu (eklemeniz gerekiyor)
String _formatTarih(DateTime tarih) {
  return '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year} ${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}';
}

  // Duruma göre renk
  Color _getDurumRengi(String durum) {
    switch (durum) {
      case 'Lobide':
        return Colors.blue;
      case 'Atolye Sevk':
        return Colors.orange;
      case 'Test Ünitesi Sevk':
        return Colors.purple;
      case 'Teslime Hazır':
        return Colors.green;
      case 'Çıkış Yapıldı':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}