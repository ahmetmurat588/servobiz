import 'package:flutter/material.dart';
import 'models/onay_istegi.dart';
import 'services/onay_servisi.dart';
import 'services/kimlik_dogrulama.dart';
import 'services/bildirim_servisi.dart';

class OnayBekleyenlerSayfasi extends StatefulWidget {
  const OnayBekleyenlerSayfasi({super.key});

  @override
  State<OnayBekleyenlerSayfasi> createState() => _OnayBekleyenlerSayfasiState();
}

class _OnayBekleyenlerSayfasiState extends State<OnayBekleyenlerSayfasi> {
  final OnayServisi _onayServisi = OnayServisi();
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();
  final BildirimServisi _bildirimServisi = BildirimServisi();

  List<OnayIstegi> _istekler = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  void _verileriYukle() {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return;

    setState(() {
      _yukleniyor = true;
    });

    // Onaylayabileceği istekleri al
    _istekler = _onayServisi.onaylayabilecekIstekler(kullanici.email);
    
    setState(() {
      _yukleniyor = false;
    });
  }

  Future<void> _onayla(OnayIstegi istek) async {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onay İsteği'),
        content: Text(
          '${istek.cihazServoBizNo} numaralı cihazın durumunu '
          '"${istek.mevcutDurum}" → "${istek.istenenDurum}" olarak değiştirmek istiyor.\n\n'
          'İsteyen: ${istek.isteyenAd}\n'
          '${istek.not != null ? 'Not: ${istek.not}' : ''}\n\n'
          'Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _reddet(istek);
            },
            child: const Text('Reddet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (onay == true) {
      final basarili = await _onayServisi.onayla(istek.id, kullanici.email);
      if (basarili) {
        // Bildirim gönder
        await _bildirimServisi.onayIstegiSonuclandi(
          istek.cihazServoBizNo,
          istek.istenenDurum,
          true,
          kullanici.adSoyad,
        );
        _showSuccess('İstek onaylandı ve cihaz durumu güncellendi!');
        _verileriYukle();
      } else {
        _showHata('Onaylama başarısız');
      }
    }
  }

  Future<void> _reddet(OnayIstegi istek) async {
    final kullanici = _auth.aktifoKullanici;
    if (kullanici == null) return;

    final basarili = await _onayServisi.reddet(istek.id, kullanici.email);
    if (basarili) {
      // Bildirim gönder
      await _bildirimServisi.onayIstegiSonuclandi(
        istek.cihazServoBizNo,
        istek.istenenDurum,
        false,
        kullanici.adSoyad,
      );
      _showSuccess('İstek reddedildi');
      _verileriYukle();
    } else {
      _showHata('Reddetme başarısız');
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
          "ONAY BEKLEYENLER",
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _istekler.isEmpty
                ? _buildBosEkran()
                : _buildIstekListesi(),
      ),
    );
  }

  Widget _buildBosEkran() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "Bekleyen onay isteği bulunmuyor",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIstekListesi() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _istekler.length,
      itemBuilder: (context, index) {
        return _buildIstekKarti(_istekler[index]);
      },
    );
  }

  Widget _buildIstekKarti(OnayIstegi istek) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  istek.cihazServoBizNo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F2E6D),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'Beklemede',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),

            // Durum değişikliği
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Mevcut', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          istek.mevcutDurum,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('İstenen', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          istek.istenenDurum,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // İsteyen kişi
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'İsteyen: ${istek.isteyenAd}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tarih
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Tarih: ${_formatTarih(istek.istekTarihi)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),

            // Not varsa göster
            if (istek.not != null && istek.not!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not: ${istek.not}',
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Butonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _reddet(istek),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => _onayla(istek),
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text('Onayla', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTarih(DateTime tarih) {
    return '${tarih.day.toString().padLeft(2, '0')}/'
        '${tarih.month.toString().padLeft(2, '0')}/'
        '${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }
}
