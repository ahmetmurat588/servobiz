import 'package:flutter/material.dart';
import '../services/email_validator.dart';
import '../services/kimlik_dogrulama.dart';

class GirisDialog extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const GirisDialog({required this.onLoginSuccess});

  @override
  State<GirisDialog> createState() => _GirisDialogState();
}

class _GirisDialogState extends State<GirisDialog> {
  bool _ekranGiris = true; // true: giris, false: kayit ol
  
  final _girisController = TextEditingController();
  final _sifreController = TextEditingController();
  
  final _adSoyadController = TextEditingController();
  final _kullaniciAdiController = TextEditingController();
  final _emailKayitController = TextEditingController();
  final _sifreKayitController = TextEditingController();
  final _sifreKayitTekrarController = TextEditingController();
  
  final _emailVerifyController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  int _kayitAsama = 0; // 0: bilgiler, 1: Email Dogrulama, 2: tamamlandi
  String? _selectedEmail;
  String? _selectedKullaniciAdi;
  String? _selectedAdSoyad;
  bool _yukleniyor = false;
  
  // Dialog içi mesaj gösterimi
  String? _mesaj;
  bool _mesajHata = false;
  
  // Şifre görünürlüğü
  bool _sifreGoster = false;
  bool _sifreKayitGoster = false;
  bool _sifreTekrarGoster = false;

  final KimlkiDogrulamaSistemi _auth = KimlkiDogrulamaSistemi();

  @override
  void initState() {
    super.initState();
  }

  // Giris yap - email veya kullanici adi ile
  Future<void> _girisYap() async {
    final emailVeyaKullaniciAdi = _girisController.text.trim();
    final sifre = _sifreController.text.trim();

    if (emailVeyaKullaniciAdi.isEmpty || sifre.isEmpty) {
      _showError('Lutfen tum alanlari doldurunuz.');
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      // Önce kullanıcı/email var mı kontrol et
      if (!_auth.emailVeyaKullaniciAdiVarMi(emailVeyaKullaniciAdi)) {
        setState(() => _yukleniyor = false);
        _showError('Kayıtlı kullanıcı/email bulunamadı!');
        return;
      }

      final basarili = await _auth.girisYap(emailVeyaKullaniciAdi, sifre);
      
      setState(() => _yukleniyor = false);
      
      if (basarili) {
        _showSuccess('Giriş başarılı! Hoş geldiniz.');
        widget.onLoginSuccess();
        Navigator.of(context).pop();
      } else {
        _showError('Hatalı şifre!');
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
      _showError('Hata: $e');
    }
  }

  // Kayit icin devam et - dogrulama kodu gonder
  Future<void> _devamEt() async {
    final kullaniciAdi = _kullaniciAdiController.text.trim();
    final email = _emailKayitController.text.trim();
    final sifre = _sifreKayitController.text.trim();
    final sifreTekrar = _sifreKayitTekrarController.text.trim();

    if (kullaniciAdi.isEmpty || email.isEmpty || sifre.isEmpty) {
      _showError('Lütfen tüm alanları doldurunuz.');
      return;
    }

    if (!EmailValidator.isValidEmail(email)) {
      _showError('Geçerli bir email adresi giriniz.');
      return;
    }

    // Email kontrolu
    if (_auth.emailVarMi(email)) {
      _showError('Bu email adresi zaten kayıtlı.');
      return;
    }

    // Kullanici adi kontrolu
    if (_auth.kullaniciAdiVarMi(kullaniciAdi)) {
      _showError('Bu kullanıcı adı zaten alınmış.');
      return;
    }

    if (sifre != sifreTekrar) {
      _showError('Şifreler eşleşmiyor.');
      return;
    }

    if (sifre.length < 6) {
      _showError('Şifre en az 6 karakter olmalıdır.');
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      // Dogrulama kodu gonder
      final kodGonderildi = await _auth.dogrulamaKoduGonder(email);
      
      setState(() => _yukleniyor = false);
      
      if (kodGonderildi) {
        // Email'i normalize ederek sakla (tutarlılık için)
        _selectedEmail = email.trim().toLowerCase();
        _selectedKullaniciAdi = kullaniciAdi;
        _selectedAdSoyad = kullaniciAdi; // Kullanici adi olarak ayarla
        print('📝 Email kaydedildi: $_selectedEmail');
        setState(() => _kayitAsama = 1);
        _showSuccess('Doğrulama kodu email adresinize gönderildi.');
      } else {
        _showError('Doğrulama kodu gönderilemedi. Lütfen tekrar deneyiniz.');
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
      _showError('Hata: $e');
    }
  }

  // Dogrulama kodunu dogrula
  Future<void> _dogrulamaKoduDogrula() async {
    // Çift tıklamayı engelle
    if (_yukleniyor) return;
    
    final kod = _verificationCodeController.text.trim();

    if (kod.isEmpty || kod.length != 6) {
      _showError('Lütfen 6 haneli kodu giriniz.');
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      print('🔐 Doğrulama başlatılıyor: email=$_selectedEmail, kod=$kod');
      final basarili = await _auth.dogrulamaKoduDogrula(_selectedEmail!, kod);
      print('🔐 Doğrulama sonucu: $basarili');
      
      if (basarili) {
        // Email dogrulandi, simdi kayit yap
        await _kayitTamamla();
      } else {
        setState(() => _yukleniyor = false);
        _showError('Hatalı kod. Lütfen tekrar deneyiniz.');
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
      _showError('Hata: $e');
    }
  }

  // Kaydi tamamla
  Future<void> _kayitTamamla() async {
    try {
      final basarili = await _auth.yeniKullaniciKaydet(
        email: _selectedEmail!,
        kullaniciAdi: _selectedKullaniciAdi!,
        adSoyad: _selectedAdSoyad!,
        sifre: _sifreKayitController.text.trim(),
      );
      
      setState(() => _yukleniyor = false);

      if (basarili) {
        _showSuccess('Kayıt tamamlandı! Hoş geldiniz.');
        setState(() => _kayitAsama = 2);

        Future.delayed(Duration(seconds: 2), () {
          widget.onLoginSuccess();
          Navigator.of(context).pop();
        });
      } else {
        _showError('Kayıt sırasında hata oluştu. Lütfen tekrar deneyiniz.');
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
      _showError('Hata: $e');
    }
  }

  // Şifremi Unuttum
  Future<void> _sifremiUnuttum() async {
    final emailVeyaKullaniciAdi = _girisController.text.trim();

    if (emailVeyaKullaniciAdi.isEmpty) {
      _showError('Lütfen email veya kullanıcı adınızı girin.');
      return;
    }

    // Kullanıcı var mı kontrol et
    if (!_auth.emailVeyaKullaniciAdiVarMi(emailVeyaKullaniciAdi)) {
      _showError('Kayıtlı kullanıcı/email bulunamadı!');
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final sonuc = await _auth.sifreSifirla(emailVeyaKullaniciAdi);
      
      setState(() => _yukleniyor = false);
      
      if (sonuc) {
        _showSuccess('Yeni şifreniz email adresinize gönderildi.');
      } else {
        _showError('Şifre sıfırlama başarısız oldu.');
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
      _showError('Hata: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _mesaj = message;
      _mesajHata = true;
    });
    // 3 saniye sonra mesajı kaldır
    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _mesaj == message) {
        setState(() => _mesaj = null);
      }
    });
  }

  void _showSuccess(String message) {
    setState(() {
      _mesaj = message;
      _mesajHata = false;
    });
    // 3 saniye sonra mesajı kaldır
    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _mesaj == message) {
        setState(() => _mesaj = null);
      }
    });
  }

  // Mesaj widget'ı
  Widget _mesajWidget() {
    if (_mesaj == null) return SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _mesajHata ? Colors.red.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _mesajHata ? Colors.red.shade400 : Colors.green.shade400,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _mesajHata ? Icons.error_outline : Icons.check_circle_outline,
            color: _mesajHata ? Colors.red.shade700 : Colors.green.shade700,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _mesaj!,
              style: TextStyle(
                color: _mesajHata ? Colors.red.shade800 : Colors.green.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _mesaj = null),
            child: Icon(
              Icons.close,
              color: _mesajHata ? Colors.red.shade700 : Colors.green.shade700,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _temizle() {
    _girisController.clear();
    _sifreController.clear();
    _adSoyadController.clear();
    _kullaniciAdiController.clear();
    _emailKayitController.clear();
    _sifreKayitController.clear();
    _sifreKayitTekrarController.clear();
    _emailVerifyController.clear();
    _verificationCodeController.clear();
    setState(() {
      _kayitAsama = 0;
      _selectedEmail = null;
      _selectedKullaniciAdi = null;
      _selectedAdSoyad = null;
    });
  }

  @override
  void dispose() {
    _girisController.dispose();
    _sifreController.dispose();
    _adSoyadController.dispose();
    _kullaniciAdiController.dispose();
    _emailKayitController.dispose();
    _sifreKayitController.dispose();
    _sifreKayitTekrarController.dispose();
    _emailVerifyController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _ekranGiris 
          ? _girisEkrani() 
          : (_kayitAsama == 0 
              ? _kayitEkrani() 
              : (_kayitAsama == 1 
                  ? _emailDogrulamaEkrani() 
                  : _kayitTamamlandiEkrani())),
      ),
    );
  }

  // Giris Ekrani
  Widget _girisEkrani() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve Kapat butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.login, color: Colors.blue.shade900, size: 24),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Giriş Yap',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              // Sağ üst X butonu
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.grey.shade700, size: 20),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Mesaj alanı
          _mesajWidget(),

          // Email veya Kullanıcı Adı
          TextField(
            controller: _girisController,
            decoration: InputDecoration(
              labelText: 'Email veya Kullanıcı Adı',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Icon(Icons.person, color: Colors.blue.shade700),
            ),
          ),
          SizedBox(height: 15),

          // Şifre
          TextField(
            controller: _sifreController,
            obscureText: !_sifreGoster,
            decoration: InputDecoration(
              labelText: 'Şifre',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Icon(Icons.lock, color: Colors.blue.shade700),
              suffixIcon: IconButton(
                icon: Icon(
                  _sifreGoster ? Icons.visibility : Icons.visibility_off,
                  color: Colors.blue.shade700,
                ),
                onPressed: () => setState(() => _sifreGoster = !_sifreGoster),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Giris Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _yukleniyor ? null : _girisYap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _yukleniyor
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Giriş Yap', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          SizedBox(height: 15),

          // Kayıt Ol linki
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hesabınız yok mu? '),
              TextButton(
                onPressed: () {
                  setState(() {
                    _ekranGiris = false;
                    _temizle();
                  });
                },
                child: Text('Kayıt Ol', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // Şifremi Unuttum
          TextButton(
            onPressed: _yukleniyor ? null : _sifremiUnuttum,
            child: Text('Şifremi Unuttum', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // Kayit Ekrani
  Widget _kayitEkrani() {
    final sifreEslesme = _sifreKayitController.text == _sifreKayitTekrarController.text &&
        _sifreKayitController.text.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baslik
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add, color: Colors.blue.shade900, size: 24),
              ),
              SizedBox(width: 10),
              Text(
                'Kayıt Ol',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Mesaj alanı
          _mesajWidget(),

          // Kullanıcı Adı
          TextField(
            controller: _kullaniciAdiController,
            decoration: InputDecoration(
              labelText: 'Kullanıcı Adı',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Icon(Icons.alternate_email, color: Colors.blue.shade700),
              hintText: 'örnek: ahmet_yilmaz',
            ),
          ),
          SizedBox(height: 15),

          // Email
          TextField(
            controller: _emailKayitController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Icon(Icons.email, color: Colors.blue.shade700),
            ),
          ),
          SizedBox(height: 15),

          // Şifre
          TextField(
            controller: _sifreKayitController,
            obscureText: !_sifreKayitGoster,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Şifre (min 6 karakter)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Icon(Icons.lock, color: Colors.blue.shade700),
              suffixIcon: IconButton(
                icon: Icon(
                  _sifreKayitGoster ? Icons.visibility : Icons.visibility_off,
                  color: Colors.blue.shade700,
                ),
                onPressed: () => setState(() => _sifreKayitGoster = !_sifreKayitGoster),
              ),
            ),
          ),
          SizedBox(height: 15),

          // Şifre Tekrar
          TextField(
            controller: _sifreKayitTekrarController,
            obscureText: !_sifreTekrarGoster,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Şifre Tekrar',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade700),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sifreKayitTekrarController.text.isNotEmpty)
                    Icon(sifreEslesme ? Icons.check_circle : Icons.error, color: sifreEslesme ? Colors.green : Colors.red),
                  IconButton(
                    icon: Icon(
                      _sifreTekrarGoster ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue.shade700,
                    ),
                    onPressed: () => setState(() => _sifreTekrarGoster = !_sifreTekrarGoster),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Kayit Ol Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _yukleniyor ? null : _devamEt,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _yukleniyor
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Devam Et', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          SizedBox(height: 15),

          // Giriş Yap linki
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Zaten hesabınız var mı? '),
              TextButton(
                onPressed: () {
                  setState(() {
                    _ekranGiris = true;
                    _temizle();
                  });
                },
                child: Text('Giriş Yap', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // Kapat Butonu
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Kapat', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // Email Dogrulama Ekrani
  Widget _emailDogrulamaEkrani() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baslik
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.email, color: Colors.orange.shade900, size: 24),
              ),
              SizedBox(width: 10),
              Text(
                'Email Doğrulama',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Mesaj alanı
          _mesajWidget(),

          // Bilgi metni
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.mark_email_read, color: Colors.orange.shade700, size: 40),
                SizedBox(height: 10),
                Text(
                  '$_selectedEmail adresine doğrulama kodu gönderilmiştir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Doğrulama Kodu
          TextField(
            controller: _verificationCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Doğrulama Kodu',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              counterText: '',
            ),
          ),
          SizedBox(height: 20),

          // Doğrula Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _yukleniyor ? null : _dogrulamaKoduDogrula,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _yukleniyor
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Dogrula', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          SizedBox(height: 15),

          // Kodu Tekrar Gönder
          TextButton.icon(
            onPressed: _yukleniyor ? null : () async {
              setState(() => _yukleniyor = true);
              _verificationCodeController.clear();
              
              // Yeni kod gönder (eski kod otomatik değişir)
              final basarili = await _auth.dogrulamaKoduGonder(_selectedEmail!);
              
              setState(() => _yukleniyor = false);
              
              if (basarili) {
                _showSuccess('Yeni doğrulama kodu gönderildi.');
              } else {
                _showError('Kod gönderilemedi. Lütfen tekrar deneyiniz.');
              }
            },
            icon: Icon(Icons.refresh, color: Colors.blue.shade700),
            label: Text('Kodu Tekrar Gönder', style: TextStyle(color: Colors.blue.shade700)),
          ),

          // Geri Don
          TextButton(
            onPressed: () {
              setState(() {
                _kayitAsama = 0;
                _verificationCodeController.clear();
              });
            },
            child: Text('Geri Don', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // Kayit Tamamlandi Ekrani
  Widget _kayitTamamlandiEkrani() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: Colors.blue.shade700, size: 60),
          ),
          SizedBox(height: 20),
          Text(
            'Kayit Tamamlandi!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Hos geldiniz, $_selectedKullaniciAdi',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          SizedBox(height: 10),
          Text(
            'Yonlendiriliyorsunuz...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 20),
          CircularProgressIndicator(color: Colors.blue.shade700),
        ],
      ),
    );
  }
}
