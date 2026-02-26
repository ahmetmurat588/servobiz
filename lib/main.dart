import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'yeni_cihaz.dart';
import 'cihaz_guncelle.dart';
import 'cihaz_sorgula.dart';
import 'yetkilendirme_sayfasi.dart';
import 'models/cihaz.dart';
import 'models/kullanici.dart';
import 'services/kimlik_dogrulama.dart';
import 'services/yetkilendirme_sistemi.dart';
import 'services/cihaz_servisi.dart';
import 'services/onay_servisi.dart';
import 'services/bildirim_servisi.dart';
import 'dialogs/giris_dialog.dart';
import 'dialogs/kullanici_duzenle_dialog.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase başlat
  await Firebase.initializeApp();
  
  // Tüm servisleri PARALEL başlat (çok daha hızlı)
  await Future.wait([
    BildirimServisi().init(),
    KimlkiDogrulamaSistemi().init(),
    CihazServisi().init(),
    OnayServisi().init(),
    YetkilendirmeSistemi().init(),
  ]);
  
  runApp(ServoBizApp());
}

class ServoBizApp extends StatelessWidget {
  const ServoBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ServoBiz',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  bool isLoggedIn = false;
  Kullanici? aktifoKullanici;
  
  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();
  final YetkilendirmeSistemi _yetkiSistemi = YetkilendirmeSistemi();
  final CihazServisi _cihazServisi = CihazServisi();

  @override
  void initState() {
    super.initState();
    _oturumKontrol();
  }

  Future<void> _oturumKontrol() async {
    if (_auth.oturumAcikMi) {
      setState(() {
        isLoggedIn = true;
        aktifoKullanici = _auth.aktifoKullanici;
      });
    }
  }

  Future<void> _showLoginPopup() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GirisDialog(
          onLoginSuccess: () {
            setState(() {
              isLoggedIn = true;
              aktifoKullanici = _auth.aktifoKullanici;
            });
          },
        );
      },
    );
  }

  Future<void> _cikis() async {
    // Tek bir doğrulama dialog'u göster
    final bool? cikisOnay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.blue.shade50],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üst kısım - ikon
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),
                
                // Başlık
                Text(
                  'Çıkış Yap',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 10),
                
                // Mesaj
                Text(
                  'Hesabınızdan çıkış yapmak üzeresiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 5),
                
                // Kullanıcı adı
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    aktifoKullanici?.adSoyad ?? 'Kullanıcı',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Uyarı kutusu
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Çıkış yaptıktan sonra tekrar giriş yapmanız gerekecektir.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25),
                
                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(false); // İptal
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(true); // Çıkış onay
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Çıkış Yap',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // Kullanıcı çıkışı onayladıysa
    if (cikisOnay == true) {
      setState(() {
        isLoggedIn = false;
        aktifoKullanici = null;
      });
      _auth.cikisYap();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Başarıyla çıkış yapıldı.'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0F2E6D),
        elevation: 0,
        toolbarHeight: 40, // Kısa AppBar
        title: null,
        centerTitle: false,
        actions: [], // Actions'ı tamamen boşalttık
      ),
      body: Stack(
        children: [
          // Ana içerik
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A3C8B), Color(0xFF5F87D6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: 10 , bottom: 30),
                  color: Color(0xFF0F2E6D),
                  child: Center(
                    child: Text(
                      "SERVOBİZ ATÖLYE CİHAZ DURUMU",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 80),

                _menuButton(context, "YENİ CİHAZ KAYDET", YeniCihazSayfasi()),
                SizedBox(height: 25),
                _menuButton(context, "CİHAZ DURUMU GÜNCELLE", CihazGuncelleSayfasi()),
                SizedBox(height: 25),
                _menuButton(context, "CİHAZ LİSTESİ", CihazSorgulaSayfasi()),
                SizedBox(height: 25),
                
                // Yetkilendirme butonu - sadece admin için
                if (isLoggedIn && aktifoKullanici != null && _yetkiSistemi.adminMi(aktifoKullanici!.email))
                  SizedBox(
                    width: 250,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => YetkilendirmeSayfasi()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'YETKİLENDİRME',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 30),
                if (!isLoggedIn)
                  SizedBox(
                    width: 150,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 16, 144, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showLoginPopup,
                      child: Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Kullanıcı bilgileri - En altta sağda
          if (isLoggedIn)
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: () async {
                  // Kullanıcı düzenleme dialog'unu aç
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return KullaniciDuzenleDialog(
                        kullanici: aktifoKullanici!,
                        onUpdateSuccess: () {
                          setState(() {}); // Sayfayı güncelle
                        },
                      );
                    },
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF0F2E6D),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Login simgesi (sol tarafta)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF0F2E6D),
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 10),
                      // Kullanıcı bilgileri (sağ tarafta)
                      Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      aktifoKullanici?.adSoyad ?? 'Kullanıcı',
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
    // Çıkış Yap butonu ayrı bir GestureDetector olarak
    GestureDetector(
      onTap: () {
        _cikis(); // Doğrudan çıkış fonksiyonunu çağır
      },
      child: Text(
        'Çıkış Yap',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  ],
),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _menuButton(BuildContext context, String text, Widget page) {
    return SizedBox(
      width: 250,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromARGB(255, 16, 144, 255),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isLoggedIn
            ? () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => page),
                );

                // Yeni cihaz kaydedildiyse sayfayı yenile (cihaz zaten serviste ekli)
                if (result is Cihaz || result == true) {
                  setState(() {});
                }
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lütfen giriş yapınız.'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
              },
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
