import 'package:flutter/material.dart';
import '../models/kullanici.dart';
import '../services/kimlik_dogrulama.dart';

class KullaniciDuzenleDialog extends StatefulWidget {
  final Kullanici kullanici;
  final Function() onUpdateSuccess;

  const KullaniciDuzenleDialog({
    super.key,
    required this.kullanici,
    required this.onUpdateSuccess,
  });

  @override
  State<KullaniciDuzenleDialog> createState() => _KullaniciDuzenleDialogState();
}

class _KullaniciDuzenleDialogState extends State<KullaniciDuzenleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _auth = KimlkiDogrulamaSistemi();
  
  late TextEditingController _emailController;
  late TextEditingController _kullaniciAdiController;
  late TextEditingController _eskiSifreController;
  late TextEditingController _yeniSifreController;
  late TextEditingController _yeniSifreTekrarController;
  late TextEditingController _verificationCodeController;
  
  bool _isLoading = false;
  bool _sifreDegistir = false;
  int _duzenlemeAsama = 0; // 0: bilgiler, 1: email doğrulama (email değiştiyse)
  String? _yeniEmail;
  String? _yeniKullaniciAdi;
  String? _yeniSifre;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.kullanici.email);
    _kullaniciAdiController = TextEditingController(text: widget.kullanici.kullaniciAdi);
    _eskiSifreController = TextEditingController();
    _yeniSifreController = TextEditingController();
    _yeniSifreTekrarController = TextEditingController();
    _verificationCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _kullaniciAdiController.dispose();
    _eskiSifreController.dispose();
    _yeniSifreController.dispose();
    _yeniSifreTekrarController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  // İlk adım: Bilgileri kontrol et
  Future<void> _bilgileriKontrolEt() async {
    if (!_formKey.currentState!.validate()) return;

    final yeniEmail = _emailController.text.trim();
    final yeniKullaniciAdi = _kullaniciAdiController.text.trim();
    final eskiSifre = _eskiSifreController.text;
    final yeniSifre = _sifreDegistir ? _yeniSifreController.text : null;

    // Şifreyi doğrula
    final sifreDogru = await _auth.sifreKontrolEt(widget.kullanici.email, eskiSifre);
    
    if (!sifreDogru) {
      _showError('Şifreniz hatalı!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool emailDegisti = yeniEmail != widget.kullanici.email;
      bool kullaniciAdiDegisti = yeniKullaniciAdi != widget.kullanici.kullaniciAdi;
      
      // Email değiştiyse kontrol et
      if (emailDegisti) {
        if (_auth.emailVarMi(yeniEmail)) {
          setState(() => _isLoading = false);
          _showError('Bu email adresi zaten kullanılıyor!');
          return;
        }
      }

      // Kullanıcı adı değiştiyse kontrol et
      if (kullaniciAdiDegisti) {
        if (_auth.kullaniciAdiVarMi(yeniKullaniciAdi)) {
          setState(() => _isLoading = false);
          _showError('Bu kullanıcı adı zaten alınmış!');
          return;
        }
      }

      // Email değiştiyse doğrulama kodu gönder
      if (emailDegisti) {
        print('📧 Yeni email için doğrulama kodu gönderiliyor: $yeniEmail');
        final basarili = await _auth.dogrulamaKoduGonder(yeniEmail);
        
        setState(() => _isLoading = false);

        if (basarili) {
          // Geçici verileri kaydet
          _yeniEmail = yeniEmail;
          _yeniKullaniciAdi = yeniKullaniciAdi;
          _yeniSifre = yeniSifre;
          
          _showSuccess('Doğrulama kodu yeni email adresinize gönderildi.');
          setState(() => _duzenlemeAsama = 1);
        } else {
          _showError('Doğrulama kodu gönderilemedi. Lütfen tekrar deneyin.');
        }
      } else {
        // Email değişmedi, direkt güncelle
        setState(() => _isLoading = false);
        await _kullaniciGuncelle(
          yeniEmail, 
          yeniKullaniciAdi, 
          eskiSifre, 
          yeniSifre
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Hata: $e');
    }
  }

  // İkinci adım: Doğrulama kodunu kontrol et
  Future<void> _dogrulamaKoduDogrula() async {
    final kod = _verificationCodeController.text.trim();

    if (kod.isEmpty || kod.length != 6) {
      _showError('Lütfen 6 haneli kodu giriniz.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final basarili = await _auth.dogrulamaKoduDogrula(_yeniEmail!, kod);
      
      setState(() => _isLoading = false);

      if (basarili) {
        // Doğrulama başarılı, kullanıcıyı güncelle
        await _kullaniciGuncelle(
          _yeniEmail!,
          _yeniKullaniciAdi!,
          _eskiSifreController.text,
          _yeniSifre,
        );
      } else {
        _showError('Hatalı doğrulama kodu. Lütfen tekrar deneyiniz.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Hata: $e');
    }
  }

  // Kullanıcı bilgilerini güncelle
  Future<void> _kullaniciGuncelle(
    String email, 
    String kullaniciAdi, 
    String eskiSifre, 
    String? yeniSifre
  ) async {
    setState(() => _isLoading = true);

    try {
      final success = await _auth.kullaniciGuncelle(
        yeniEmail: email,
        yeniKullaniciAdi: kullaniciAdi,
        yeniAdSoyad: kullaniciAdi,
        eskiSifre: eskiSifre,
        yeniSifre: yeniSifre,
      );

      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).pop();
        widget.onUpdateSuccess();
        
        _showSuccess('Bilgileriniz başarıyla güncellendi.');
      } else {
        _showError('Güncelleme başarısız! Lütfen tekrar deneyin.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Hata: $e');
    }
  }

  void _showError(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        child: _duzenlemeAsama == 0 ? _bilgiFormu() : _dogrulamaFormu(),
      ),
    );
  }

  // Bilgi düzenleme formu
  Widget _bilgiFormu() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Colors.blue.shade900,
                    size: 24,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Bilgilerimi Düzenle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.email, color: Colors.blue.shade700),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'E-posta gerekli';
                }
                if (!value.contains('@')) {
                  return 'Geçerli bir e-posta girin';
                }
                return null;
              },
            ),
            SizedBox(height: 15),

            // Kullanıcı Adı
            TextFormField(
              controller: _kullaniciAdiController,
              decoration: InputDecoration(
                labelText: 'Kullanıcı Adı',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.badge, color: Colors.blue.shade700),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kullanıcı adı gerekli';
                }
                if (value.length < 3) {
                  return 'Kullanıcı adı en az 3 karakter olmalı';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            // Şifre Değiştir checkbox
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _sifreDegistir,
                    onChanged: (value) {
                      setState(() {
                        _sifreDegistir = value!;
                      });
                    },
                    activeColor: Colors.blue.shade900,
                  ),
                  Expanded(
                    child: Text(
                      'Şifremi değiştirmek istiyorum',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),

            // Şifre (eski şifre)
            TextFormField(
              controller: _eskiSifreController,
              decoration: InputDecoration(
                labelText: 'Şifre',
                hintText: 'Mevcut şifrenizi girin',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.lock, color: Colors.blue.shade700),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Şifrenizi girin';
                }
                return null;
              },
            ),
            SizedBox(height: 15),

            // Yeni Şifre (opsiyonel)
            if (_sifreDegistir) ...[
              TextFormField(
                controller: _yeniSifreController,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.lock_reset, color: Colors.blue.shade700),
                ),
                obscureText: true,
                validator: (value) {
                  if (_sifreDegistir) {
                    if (value == null || value.isEmpty) {
                      return 'Yeni şifre gerekli';
                    }
                    if (value.length < 6) {
                      return 'Şifre en az 6 karakter olmalı';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),
              
              // Yeni Şifre Tekrar
              TextFormField(
                controller: _yeniSifreTekrarController,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre (Tekrar)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.lock_reset, color: Colors.blue.shade700),
                ),
                obscureText: true,
                validator: (value) {
                  if (_sifreDegistir) {
                    if (value == null || value.isEmpty) {
                      return 'Şifre tekrarı gerekli';
                    }
                    if (value != _yeniSifreController.text) {
                      return 'Şifreler eşleşmiyor';
                    }
                  }
                  return null;
                },
              ),
            ],

            SizedBox(height: 20),

            // Uyarı
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Email adresinizi değiştirirseniz, yeni adresinize doğrulama kodu gönderilecektir.',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kullanıcı adınızı değiştirirseniz, yeni kullanıcı adı ile giriş yapabilirsiniz.',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Butonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('İptal'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _bilgileriKontrolEt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text('Devam Et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Doğrulama kodu formu
  Widget _dogrulamaFormu() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email,
                  color: Colors.blue.shade900,
                  size: 24,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Email Doğrulama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          Icon(Icons.mark_email_read, size: 64, color: Colors.blue.shade900),
          SizedBox(height: 16),

          Text(
            'Yeni Email Adresiniz:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            _yeniEmail ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 8),

          Text(
            'Yeni Kullanıcı Adınız:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            _yeniKullaniciAdi ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 16),

          Text(
            'Bu adrese 6 haneli doğrulama kodu gönderilmiştir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
          SizedBox(height: 24),

          TextField(
            controller: _verificationCodeController,
            decoration: InputDecoration(
              labelText: 'Doğrulama Kodu',
              hintText: '6 haneli kodu giriniz',
              prefixIcon: Icon(Icons.code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, letterSpacing: 8),
          ),
          SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _duzenlemeAsama = 0;
                      _verificationCodeController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Geri'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _dogrulamaKoduDogrula,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Doğrula'),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '💡 Test Modunda: Konsolda görünen kodu giriniz.',
              style: TextStyle(color: Colors.orange[900], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}