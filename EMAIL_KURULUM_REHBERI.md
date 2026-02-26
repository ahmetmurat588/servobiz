# Email Doğrulama Kurulum Rehberi

## 📋 Genel Bakış

ServoBiz uygulamasında **Email ile doğrulama** sistemi tamamlandı. Kullanıcılar email adresleri ile kayıt olur ve email doğrulaması yaparlar.

---

## 🚀 Hızlı Başlangıç

### 1. Bağımlılıkları Yükle

```bash
flutter pub get
```

Bu komut otomatik olarak gerekli paketleri yükleyecektir:
- `mailer` - Email gönderme
- `email_validator` - Email doğrulama

---

## ⚙️ Konfigürasyon

### TEST MODU (Varsayılan)
Geliştirme sırasında doğrulama kodları konsola yazılır.

**Dosya:** `lib/services/email_servisi.dart`

```dart
static const bool useTestMode = true; // ✅ Varsayılan
```

Bu modda:
- Doğrulama kodları **Android Studio Console** veya **VS Code Debug Console**'da görülür
- Hiçbir dış API çağrısı yapılmaz
- İnternet bağlantısı gerekli değil

---

## 📧 GERÇEK EMAIL GÖNDERİM KURULUMU

### Gmail Kullanarak (Tavsiye Edilir)

#### 1.1 Gmail Ayarları

Gmail'den uygulama şifresi oluşturmanız gerekir:

1. **Google hesabınıza tercihlere gidin:**
   - https://myaccount.google.com

2. **"Güvenlik" bölümüne git**
   - Sol menüden "Güvenlik" seç

3. **"2-Adım Doğrulama"yı aktif et**
   - Eğer aktif değilse, önce bunu yapmanız gerekir

4. **"Uygulama Şifreleri" oluştur**
   - Güvenlik bölümünde "Uygulama Şifreleri" seçeneğini ara
   - "Mail" ve "Windows Bilgisayarı" seç
   - **App Password** (uygulama şifresi) oluştur
   - Bu 16 karakterlik şifreyi kaydet

#### 1.2 Kodda Yapılandır

**Dosya:** `lib/services/email_servisi.dart`

```dart
// Gmail konfigürasyonu
static const String senderEmail = 'yourname@gmail.com'; // Gmail adresi
static const String senderPassword = 'xxxx xxxx xxxx xxxx'; // App Password (16 karakter)

// Test modu kapat
static const bool useTestMode = false; // ✅ Değiştir
```

#### ✅ Örnek:
```dart
static const String senderEmail = 'servobiz@gmail.com';
static const String senderPassword = 'abcd efgh ijkl mnop'; // Google App Password
static const bool useTestMode = false;
```

---

### Outlook/Hotmail Kullanarak

#### İnstruktif Kurulum

1. Outlook hesabına gir
2. Hesap ayarlarından "Güvenlik" seç
3. "Uygulama şifresi" oluştur

**Kodda Yapılandır:**

```dart
static const String senderEmail = 'yourname@outlook.com';
static const String senderPassword = 'YOUR_APP_PASSWORD';
static const String smtpHost = 'smtp-mail.outlook.com';
static const int smtpPort = 587;
```

---

### Yahoo Mail Kullanarak

1. Yahoo hesabına gir
2. Account Security sayfasından App Password oluştur
3. Kodda yapılandır:

```dart
static const String senderEmail = 'yourname@yahoo.com';
static const String senderPassword = 'YOUR_APP_PASSWORD';
static const String smtpHost = 'smtp.mail.yahoo.com';
static const int smtpPort = 587;
```

---

## 🧪 TEST ETME

### 1. Uygulamayı Çalıştır
```bash
flutter run
```

### 2. Test Email Adresi

**TEST MODU:** Herhangi bir email
- Örn: `test@example.com` girebilirsiniz

**GERÇEK EMAIL:** Kontrol edebileceğiniz kendi email'iniz
- Örn: `yourname@gmail.com`

### 3. Kayıt Süreci

1. "Kayıt Ol" butonuna tıkla
2. Ad, email ve şifre gir
3. "Devam Et" tıkla
4. **TEST MODU:** Konsola doğrulama kodu yazılır
5. **GERÇEK EMAIL:** Email'ine doğrulama kodu gelir
6. Kodu gir ve doğrula
7. Kayıt tamamlanır ✅

### Konsol Çıktısını İzle

**TEST MODU çıktısı:**
```
═════════════════════════════════════════════════
📧 TEST MODU - DOĞRULAMA KODU:
╠═ Email: user@example.com
╠═ KOD: 456789
╠═ AÇIKLAMA: Bu bir test kodudur
╠═ GEÇERLİLİK: 10 dakika
═════════════════════════════════════════════════
```

**GERÇEK EMAIL çıktısı:**
```
📧 Doğrulama kodu gönderiliyor: user@example.com
✅ Email başarıyla gönderildi: user@example.com
```

---

## 🔐 Güvenlik Uyarıları

⚠️ **ÖNEMLİ:**

1. **App Password, normal şifre DEĞİLDİR**
   - Google tarafından verilen 16 karakterlik özel şifre kullanın
   - Normal Gmail şifresi çalışmaz

2. **API bilgilerini asla ver kontrol sistemine koyma** (Git, GitHub)
   ```bash
   # .env dosyası oluştur ve .gitignore'a ekle
   SENDER_EMAIL=yourname@gmail.com
   SENDER_PASSWORD=xxxx xxxx xxxx xxxx
   ```

3. **Flutter ortamı değişkenleri:**
   ```bash
   flutter run --dart-define=SENDER_EMAIL=yourname@gmail.com --dart-define=SENDER_PASSWORD='xxxx xxxx xxxx xxxx'
   ```

4. **Üretimde backend kullanın**
   - Email gönderme işini backend'e taşıyın
   - Flutter'da email şifresi saklamayın

---

## 🐛 Sorun Giderme

### Problem: TEST MODUNDA KONSOLA KOD GÖRÜNMÜYORAuth

1. **Console temizleyin**
   - VS Code: Ctrl+Shift+K, Android Studio: Clear All
2. **DEBUG filter'ı kontrol edin**
   - "DEBUG" yazısının yanındaki X'e tıklayın
3. **`useTestMode = true` olduğundan emin olun**

### Problem: GERÇEK EMAIL GÖNDERILEMEZ

1. **App Password doğru mu?**
   - Google tarafından verilen 16 karakterlik şifre mi?
   - Normal Gmail şifresi değil mi?

2. **2-Adım Doğrulama yapı mı?**
   - https://myaccount.google.com/security adresine git
   - "2-Adım Doğrulama"yı kontrol et

3. **Email adresi doğru mu?**
   - Typo var mı? (örn: gamil.com yerine gmail.com)

4. **İnternet bağlantısı var mı?**
   - Cihazın internete bağlı olup olmadığını kontrol et

5. **Firewall/Proxy bloklama?**
   - Ofis ağında mısınız? Network admin'e başvurun

### Problem: "SMTP Authentication Failed"

- App Password yanlış
- 2-Adım Doğrulama kapalı
- Gerçek Gmail şifresi kullanıyorsunuz

**Çözüm:** 1.1 kısmındaki adımları yeniden yapın

### Problem: "Connection Timeout"

- İnternet bağlantısı yok
- Firewall engellev SMTP portunu (587)
- Gmail SMTP sunucusu yanıt vermiyor (nadir)

**Çözüm:** İnternet bağlantısını kontrol edin

---

## 📊 Email Servisi Sınıfı

**Dosya:** `lib/services/email_servisi.dart`

```dart
// Email ile doğrulama kodu gönder
Future<bool> dogrulamaKoduGonder(String toEmail, String verificationCode)

// Türk email sağlayıcıları için SMTP ayarları
static Map<String, dynamic> getSMTPConfig(String sağlayıcı)
  // Desteklenen: 'gmail', 'outlook', 'yahoomail'
```

---

## 📞 Kimlik Doğrulama Sınıfı

**Dosya:** `lib/services/kimlik_dogrulama.dart`

```dart
// Email ile doğrulama kodu gönder
Future<bool> dogrulamaKoduGonder(String email)

// Doğrulama kodunu doğrula
Future<bool> dogrulamaKoduDogrula(String email, String kod)

// Yeni kullanıcı kaydı
Future<bool> yeniKullaniciKaydet(String adSoyad, String email, String sifre)

// Kullanıcı girişi
Future<bool> girisYap(String email, String sifre)

// Oturumu kapat
void cikisYap()
```

---

## 📧 Email Formatı

Gönderilen email HTML formatında ve şu öğeleri içerir:

- Başlık: "ServoBiz - Email Doğrulama"
- 6 haneli doğrulama kodu
- Güvenlik ipuçları
- 10 dakika geçerlilik süresi bilgisi
- Footer: ServoBiz telif bilgisi

---

## 🔄 Doğrulama Akışı

```
1. Kullanıcı "Kayıt Ol" tıkla
   ↓
2. Ad, Email, Şifre gir
   ↓
3. "Devam Et" tıkla
   ↓
4. Doğrulama Kodu Gönder
   TEST MODU: Konsola yaz
   GERÇEK: Email gönder
   ↓
5. Email'den kodu kopyala
   ↓
6. Kodu gir ve doğrula
   ↓
7. Kayıt Tamamlandı ✅
```

---

## 📝 Demo Verileri

Test için kullanabilirsiniz:

```
Email: demo@servobiz.com
Şifre: 123456
```

Giriş ekranında bu bilgileri kullanıp giriş yapabilirsiniz.

---

## 🚀 ÜRETIM İÇİN ÖNERİLER

### 1. Backend Servisi Oluştur
```dart
// Backend endpoint
POST /api/send-verification-email
{
  "email": "user@example.com",
  "username": "John Doe"
}
```

### 2. App Password'u Backend'de Sakla
```bash
# Backend .env
SMTP_EMAIL=servobiz@gmail.com
SMTP_PASSWORD=xxxx xxxx xxxx xxxx
```

### 3. Rate Limiting Ekle
```bash
# 1 dakikada 1 kez
# Saatlik limit: 5 email
```

### 4. Email Audit Logging
```bash
# Gönderilen email'leri database'e yaz
# Başarısız gönderim'i izle
```

### 5. CDN Email Templates
```bash
# HTML template'i CDN'de sakla
# Her isteğinde indir (daha güvenli)
```

---

## 📚 Faydalı Linkler

- **Mailer Package:** https://pub.dev/packages/mailer
- **Email Validator:** https://pub.dev/packages/email_validator
- **Gmail App Passwords:** https://support.google.com/accounts/answer/185833
- **Outlook App Passwords:** https://support.microsoft.com/en-us/account-billing/manage-your-microsoft-account
- **SMTP Protokolü:** https://tools.ietf.org/html/rfc5321

---

## ✨ Özel Notlar

- Doğrulama kodları 10 dakika geçerlilidir
- Aynı email'e 1 dakikada 1 kez kod gönderilir
- Kod 6 haneli sayıdır (00000-999999 aralığında)
- Email adresleri case-sensitive değildir (otomatik lowercase)

---

**Sorularınız varsa, konsol çıktılarını kontrol edin!** 🎯

İnternet bağlantısı olmadan TEST MODUNDA geliştirmeyi devam edebilirsiniz.
