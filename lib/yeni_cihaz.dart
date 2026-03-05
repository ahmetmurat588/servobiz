import 'package:flutter/material.dart';
import 'models/cihaz.dart';
import 'services/cihaz_servisi.dart';
import 'services/bildirim_servisi.dart';
import 'services/kimlik_dogrulama.dart';

class YeniCihazSayfasi extends StatefulWidget {
  const YeniCihazSayfasi({super.key});

  @override
  State<YeniCihazSayfasi> createState() => _YeniCihazSayfasiState();
}

class _YeniCihazSayfasiState extends State<YeniCihazSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tarikhController = TextEditingController();
  final TextEditingController _seriNoController = TextEditingController();
  final TextEditingController _markaModelController = TextEditingController();
  final TextEditingController _firmaIsimiController = TextEditingController();

  final CihazServisi _cihazServisi = CihazServisi();
  final BildirimServisi _bildirimServisi = BildirimServisi();
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();

  // Otomatik ServoBiz No
  String servoBizNo = '...'; // Yüklenene kadar placeholder
  String durum = "Lobide";
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _servoBizNoYukle();
    
    // Tarih alanını bugünün tarihi ile otomatik doldur (GG/AA/YYYY format)
    final now = DateTime.now();
    _tarikhController.text = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
  
  Future<void> _servoBizNoYukle() async {
    // Firestore'dan güncel verileri çek
    await _cihazServisi.init();
    if (mounted) {
      setState(() {
        // Otomatik yeni ServoBizNo üretimi (250600n formatında)
        servoBizNo = _cihazServisi.sonrakiServoBizNo();
        _yukleniyor = false;
      });
    }
  }

  @override
  void dispose() {
    _tarikhController.dispose();
    _seriNoController.dispose();
    _markaModelController.dispose();
    _firmaIsimiController.dispose();
    super.dispose();
  }

  Future<void> _kaydetCihaz() async {
    if (_yukleniyor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bekleyin, veriler yükleniyor...'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      final seriNo = _seriNoController.text.trim();
      final markaModel = _markaModelController.text.trim();
      final firmaIsmi = _firmaIsimiController.text.trim();

      // Aynı seri numarasıyla kayıtlı cihaz kontrolü
      final seriNoEslesen = _cihazServisi.cihazlar.where((c) => c.seriNo == seriNo).toList();
      if (seriNoEslesen.isNotEmpty) {
        final devamEt = await _benzerCihazUyarisiGoster(
          seriNoEslesen, 
          'Bu seri numarasıyla kayıtlı cihaz bulundu!',
        );
        if (devamEt == null) return; // İptal edildi
        if (devamEt == 'yeniden_giris') {
          // Mevcut cihaza yönlendir
          Navigator.pop(context, {'yenidenGiris': seriNoEslesen.first});
          return;
        }
        // 'yeni_urun' seçildiyse devam et
      }

      // Aynı marka/model ve firma ile kayıtlı cihaz kontrolü
      final markaFirmaEslesen = _cihazServisi.cihazlar.where((c) => c.markaModel == markaModel && c.firmaIsmi == firmaIsmi).toList();
      if (markaFirmaEslesen.isNotEmpty) {
        final devamEt = await _benzerCihazUyarisiGoster(
          markaFirmaEslesen, 
          'Bu marka/model ve firma ile kayıtlı cihaz bulundu!',
        );
        if (devamEt == null) return; // İptal edildi
        if (devamEt == 'yeniden_giris') {
          // Mevcut cihaza yönlendir
          Navigator.pop(context, {'yenidenGiris': markaFirmaEslesen.first});
          return;
        }
        // 'yeni_urun' seçildiyse devam et
      }

      // Yeni cihaz objesini oluştur
      final yeniCihaz = Cihaz(
        servoBizNo: servoBizNo,
        tarih: _tarikhController.text,
        seriNo: seriNo,
        markaModel: markaModel,
        durum: durum,
        firmaIsmi: firmaIsmi,
      );

      // CihazServisi'ne kaydet
      await _cihazServisi.cihazEkle(yeniCihaz);

      // Bildirim gönder
      final aktifKullanici = _auth.aktifoKullanici;
      await _bildirimServisi.cihazKaydedildi(
        yeniCihaz.servoBizNo, 
        yeniCihaz.markaModel,
        kaydeden: aktifKullanici?.kullaniciAdi ?? aktifKullanici?.adSoyad,
      );

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cihaz başarıyla kaydedildi!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Cihazı geri geçerek önceki sayfaya dön
      Navigator.pop(context, yeniCihaz);
    }
  }

  /// Benzer cihaz bulunduğunda uyarı popup'ı göster
  Future<String?> _benzerCihazUyarisiGoster(List<Cihaz> eslesenCihazlar, String baslik) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                baslik,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F2E6D),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daha önce kaydedilen cihaz bilgileri:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...eslesenCihazlar.map((cihaz) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bilgiSatiri('ServoBiz No', cihaz.servoBizNo),
                    _bilgiSatiri('Tarih', cihaz.tarih),
                    _bilgiSatiri('Seri No', cihaz.seriNo),
                    _bilgiSatiri('Marka/Model', cihaz.markaModel),
                    _bilgiSatiri('Firma', cihaz.firmaIsmi ?? ''),
                    _bilgiSatiri('Durum', cihaz.durum),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              const Text(
                'Ne yapmak istiyorsunuz?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, null),
            icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
            label: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'yeniden_giris'),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Yeniden Giriş', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'yeni_urun'),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text('Yeni Ürün', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bilgiSatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$baslik:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              deger,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F2E6D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold'un arka planını temizle
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2E6D),
        elevation: 0,
        title: const Text(
          "YENİ CİHAZ KAYDET",
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
                // ServoBiz No (Sadece Gösterim)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF115A9C), width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ServoBiz No:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2E6D),
                        ),
                      ),
                      Text(
                        servoBizNo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF115A9C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tarih
                TextFormField(
                  controller: _tarikhController,
                  decoration: InputDecoration(
                    labelText: "Tarih",
                    labelStyle: const TextStyle(color: Colors.white),
                    hintText: "GG/AA/YYYY",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.white),
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
                      return 'Tarih boş bırakılamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Seri No
                TextFormField(
                  controller: _seriNoController,
                  decoration: InputDecoration(
                    labelText: "Seri No",
                    labelStyle: const TextStyle(color: Colors.white),
                    hintText: "Seri numarasını girin",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.assignment, color: Colors.white),
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
                      return 'Seri No boş bırakılamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Marka Model
                TextFormField(
                  controller: _markaModelController,
                  decoration: InputDecoration(
                    labelText: "Marka Model",
                    labelStyle: const TextStyle(color: Colors.white),
                    hintText: "Marka ve modelini girin",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.info, color: Colors.white),
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
                      return 'Marka Model boş bırakılamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Durum (Otomatik Doldurulmuş)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF115A9C), width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Durum:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2E6D),
                        ),
                      ),
                      Text(
                        durum,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF115A9C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Firma İsmi
                TextFormField(
                  controller: _firmaIsimiController,
                  decoration: InputDecoration(
                    labelText: "Firma İsmi",
                    labelStyle: const TextStyle(color: Colors.white),
                    hintText: "Firma adını girin",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.business, color: Colors.white),
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
                      return 'Firma İsmi boş bırakılamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Kaydet Butonu
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 16, 144, 255),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _kaydetCihaz,
                    child: const Text(
                      "CİHAZ KAYDET",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}