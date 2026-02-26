import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Email gönderme servisi
class EmailServisi {
  // Email konfigürasyonu - KENDİ BİLGİLERİNİZİ GİRİN
  static const String senderEmail = 'servobizmuhasebe@gmail.com';
  static const String senderPassword = 'cmdc eclj liwq nojf'; // App Password
  
  // SMTP Sunucusu (Gmail için sabit)
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;

  // Test modu
  static const bool useTestMode = false; // true = konsola yaz, false = gerçek gönder

  static final EmailServisi _instance = EmailServisi._internal();

  factory EmailServisi() {
    return _instance;
  }

  EmailServisi._internal();

  /// Email ile doğrulama kodu gönder
  Future<bool> dogrulamaKoduGonder(String toEmail, String verificationCode) async {
    try {
      print('📧 Email gönderiliyor...');
      print('📧 Alıcı: $toEmail');
      print('📧 Kod: $verificationCode');
      
      if (useTestMode) {
        _showTestMessage(toEmail, verificationCode);
        return true;
      }

      // Email mesajını oluştur
      final message = _buildVerificationEmail(toEmail, verificationCode);

      // SMTP bağlantısı oluştur
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: senderEmail,
        password: senderPassword,
        ssl: false,
        allowInsecure: true,
      );

      // Email gönder - 10 saniye timeout ile
      await send(message, smtpServer).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Email gönderimi zaman aşımına uğradı');
        },
      );
      
      print('✅ Email başarıyla gönderildi!');
      return true;
      
    } catch (e) {
      print('❌ Email gönderme hatası: $e');
      return false;
    }
  }

  /// Email mesajı oluştur
  Message _buildVerificationEmail(String toEmail, String code) {
    return Message()
      ..from = Address(senderEmail, 'ServoBiz')
      ..recipients.add(toEmail)
      ..subject = 'ServoBiz Email Doğrulama Kodu: $code'
      ..html = '''
<!DOCTYPE html>
<html>
<body>
    <h2>ServoBiz Email Doğrulama</h2>
    <p>Doğrulama kodunuz: <strong>$code</strong></p>
    <p>Bu kod 10 dakika süreyle geçerlidir.</p>
</body>
</html>
'''
      ..text = 'ServoBiz doğrulama kodunuz: $code. 10 dakika geçerlidir.';
  }

  /// Yeni şifre gönder
  Future<bool> yeniSifreGonder(String toEmail, String yeniSifre) async {
    try {
      print('📧 Yeni şifre email gönderiliyor...');
      print('📧 Alıcı: $toEmail');
      
      if (useTestMode) {
        _showTestPasswordMessage(toEmail, yeniSifre);
        return true;
      }

      // Email mesajını oluştur
      final message = _buildPasswordResetEmail(toEmail, yeniSifre);

      // SMTP bağlantısı oluştur
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: senderEmail,
        password: senderPassword,
        ssl: false,
        allowInsecure: true,
      );

      // Email gönder - 10 saniye timeout ile
      await send(message, smtpServer).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Email gönderimi zaman aşımına uğradı');
        },
      );
      
      print('✅ Yeni şifre email başarıyla gönderildi!');
      return true;
      
    } catch (e) {
      print('❌ Email gönderme hatası: $e');
      return false;
    }
  }

  /// Şifre sıfırlama email mesajı oluştur
  Message _buildPasswordResetEmail(String toEmail, String yeniSifre) {
    return Message()
      ..from = Address(senderEmail, 'ServoBiz')
      ..recipients.add(toEmail)
      ..subject = 'ServoBiz - Yeni Şifreniz'
      ..html = '''
<!DOCTYPE html>
<html>
<body>
    <h2>ServoBiz Şifre Sıfırlama</h2>
    <p>Yeni şifreniz: <strong>$yeniSifre</strong></p>
    <p>Giriş yaptıktan sonra şifrenizi değiştirmenizi öneririz.</p>
    <p>Bu işlemi siz yapmadıysanız lütfen bizimle iletişime geçin.</p>
</body>
</html>
'''
      ..text = 'ServoBiz yeni şifreniz: $yeniSifre. Giriş yaptıktan sonra şifrenizi değiştirmenizi öneririz.';
  }

  /// Test modunda konsola mesaj yaz
  void _showTestMessage(String toEmail, String code) {
    print('═════════════════════════════════════════════════');
    print('📧 TEST MODU - EMAIL DOĞRULAMA KODU:');
    print('╠═ Email: $toEmail');
    print('╠═ KOD: $code');
    print('╠═ AÇIKLAMA: Bu bir test kodudur');
    print('╠═ GEÇERLİLİK: 10 dakika');
    print('═════════════════════════════════════════════════');
  }

  /// Test modunda yeni şifre mesajı
  void _showTestPasswordMessage(String toEmail, String yeniSifre) {
    print('═════════════════════════════════════════════════');
    print('📧 TEST MODU - YENİ ŞİFRE:');
    print('╠═ Email: $toEmail');
    print('╠═ YENİ ŞİFRE: $yeniSifre');
    print('═════════════════════════════════════════════════');
  }
}