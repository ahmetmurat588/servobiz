import 'package:email_validator/email_validator.dart' as email_validator;

/// Email doğrulama ve formatlama
class EmailValidator {
  /// Email'i valide et
  /// 
  /// [email] - Kontrol edilecek email
  /// Return: true geçerli, false geçersiz
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return email_validator.EmailValidator.validate(email);
  }

  /// Email'in domain kısmını al
  /// 
  /// [email] - Email adresi (örn: user@gmail.com)
  /// Return: Domain (gmail.com)
  static String getDomain(String email) {
    if (!email.contains('@')) return '';
    return email.split('@')[1].toLowerCase();
  }

  /// Email'in kullanıcı kısmını al
  /// 
  /// [email] - Email adresi (örn: user@gmail.com)
  /// Return: Kullanıcı adı (user)
  static String getUsername(String email) {
    if (!email.contains('@')) return '';
    return email.split('@')[0];
  }

  /// Email'i normalleştir (küçük harf, boşluk kaldır)
  /// 
  /// [email] - Email adresi
  /// Return: Normalleştirilmiş email
  static String normalize(String email) {
    return email.trim().toLowerCase();
  }

  /// Yaygın email hatalarını kontrol et
  /// 
  /// [email] - Kontrol edilecek email
  /// Return: Hata mesajı (boş string = hata yok)
  static String validateAndGetError(String email) {
    email = email.trim();

    if (email.isEmpty) {
      return 'Email boş olamaz';
    }

    if (!email.contains('@')) {
      return 'Email @ işareti içermeli';
    }

    if (email.startsWith('@')) {
      return 'Email @ işaretinden önce kullanıcı adı olmalı';
    }

    if (email.endsWith('@')) {
      return 'Email @ işaretinden sonra domain olmalı';
    }

    final parts = email.split('@');
    if (parts.length > 2) {
      return 'Email yalnızca bir @ işareti içermeli';
    }

    final domain = parts[1];
    if (!domain.contains('.')) {
      return 'Domain bir nokta içermeli (örn: gmail.com)';
    }

    if (domain.endsWith('.')) {
      return 'Domain noktayla bitmemeli';
    }

    if (domain.startsWith('.')) {
      return 'Domain noktayla başlamamalı';
    }

    if (!email_validator.EmailValidator.validate(email)) {
      return 'Geçersiz email formatı';
    }

    return ''; // Hata yok
  }

  /// Sık kullanılan domain'ler için otomatik tamamlama
  /// 
  /// [username] - Kullanıcı adı (örn: user)
  /// Return: Öneriler
  static List<String> getEmailSuggestions(String username) {
    if (username.isEmpty) return [];

    const commonDomains = [
      'gmail.com',
      'outlook.com',
      'hotmail.com',
      'yahoo.com',
      'icloud.com',
      'mail.com',
    ];

    return [
      for (final domain in commonDomains) '$username@$domain',
    ];
  }

  /// Yaygın yazım hataları
  static const Map<String, String> commonTypos = {
    'gmial.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gmil.com': 'gmail.com',
    'yahooo.com': 'yahoo.com',
    'yahh.com': 'yahoo.com',
    'hotmial.com': 'hotmail.com',
    'outlo0k.com': 'outlook.com',
  };

  /// Yazım hatalarını düzelt
  /// 
  /// [email] - Email adresi
  /// Return: Düzeltilmiş email (bulunmazsa orijinal email)
  static String correctCommonTypos(String email) {
    if (!email.contains('@')) return email;

    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    var domain = parts[1].toLowerCase();

    // Yazım hatalarını kontrol et
    commonTypos.forEach((wrong, correct) {
      if (domain == wrong) {
        domain = correct;
      }
    });

    return '$username@$domain';
  }
}
