import 'package:flutter/services.dart';

// Telefon numarası formatter ve validator
class TelefonFormatter extends TextInputFormatter {
  static const String turkishPhonePattern = '+90 (5XX) XXX XX XX';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    
    // Sadece rakamları al
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    
    // Maksimum 12 rakam (90 ve sonrasında 10 rakam)
    if (digitsOnly.length > 12) {
      return oldValue;
    }

    // Formatla
    final formatted = _formatPhoneNumber(digitsOnly);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.fromPosition(TextPosition(offset: formatted.length)),
    );
  }

  static String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';
    
    // Türkiye başlangıcını kontrol et (90 veya boş başlasın)
    String normalized = digits;
    
    // Eğer 0 ile başlıyorsa 90 ile başla
    if (digits.startsWith('0')) {
      normalized = '90${digits.substring(1)}';
    }
    
    // Eğer 90 değilse başına 90 ekle
    if (!normalized.startsWith('90') && !digits.startsWith('5')) {
      if (!digits.startsWith('90')) {
        normalized = '90$digits';
      }
    }

    // Format: +90 (5XX) XXX XX XX
    if (normalized.length <= 2) {
      return '+$normalized';
    } else if (normalized.length <= 5) {
      return '+${normalized.substring(0, 2)} (${normalized.substring(2)}';
    } else if (normalized.length <= 8) {
      return '+${normalized.substring(0, 2)} (${normalized.substring(2, 5)}) ${normalized.substring(5)}';
    } else if (normalized.length <= 10) {
      return '+${normalized.substring(0, 2)} (${normalized.substring(2, 5)}) ${normalized.substring(5, 8)} ${normalized.substring(8)}';
    } else {
      return '+${normalized.substring(0, 2)} (${normalized.substring(2, 5)}) ${normalized.substring(5, 8)} ${normalized.substring(8, 10)} ${normalized.substring(10)}';
    }
  }

  static bool isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    // En az 10 rakam olmalı (5XX XXX XX XX) + 90 = 12
    if (digitsOnly.length < 12) return false;
    
    // Türkiye numarası olmalı (90 ile başlamalı)
    if (!digitsOnly.startsWith('90')) return false;
    
    // Doğru uzunluk kontrolü: 90 + 10 rakam = 12
    if (digitsOnly.startsWith('90')) {
      return digitsOnly.length == 12; // +90 + 10 rakam = 12
    }
    
    return false;
  }

  static String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  static String formatPhoneNumberDisplay(String phone) {
    return _formatPhoneNumber(cleanPhoneNumber(phone));
  }
}
