# Firebase Kurulum Rehberi - ServoBiz

Bu uygulama Firebase Firestore kullanarak çoklu cihaz senkronizasyonu sağlar. Uygulamayı çalıştırmadan önce Firebase projesini kurmanız gerekmektedir.

## 📋 Adım Adım Kurulum

### 1. Firebase Console'a Giriş Yapın
1. Tarayıcınızda [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. Google hesabınızla giriş yapın

### 2. Yeni Proje Oluşturun
1. "Proje ekle" veya "Add project" butonuna tıklayın
2. Proje adı olarak **"servobiz"** yazın
3. Google Analytics'i isteğe bağlı olarak etkinleştirin
4. "Proje oluştur" butonuna tıklayın

### 3. Android Uygulaması Ekleyin
1. Proje ana sayfasında **Android simgesine** tıklayın
2. Android paket adı: **com.example.servobiz**
3. Uygulama takma adı: **ServoBiz**
4. SHA-1 sertifikası: (şimdilik boş bırakabilirsiniz)
5. "Uygulamayı kaydet" butonuna tıklayın

### 4. google-services.json Dosyasını İndirin
1. "google-services.json indir" butonuna tıklayın
2. İndirilen dosyayı şu konuma kopyalayın:
   ```
   servobiz/android/app/google-services.json
   ```
3. "İleri" butonuna tıklayın ve kurulumu tamamlayın

### 5. Firestore Veritabanını Etkinleştirin
1. Sol menüden **"Firestore Database"** seçin
2. **"Veritabanı oluştur"** butonuna tıklayın
3. Konum olarak **"eur3 (Europe)"** veya yakın bir bölge seçin
4. **"Test modunda başlat"** seçin (geliştirme için)
5. "Etkinleştir" butonuna tıklayın

### 6. Firestore Güvenlik Kuralları (Üretim için)
Test aşamasından sonra güvenlik kurallarını güncelleyin:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Kimlik doğrulaması yapılmış kullanıcılar tüm verilere erişebilir
    match /{document=**} {
      allow read, write: if true;  // Test için
      // Üretim için: allow read, write: if request.auth != null;
    }
  }
}
```

## 📁 Firestore Koleksiyonları

Uygulama aşağıdaki koleksiyonları otomatik oluşturur:

| Koleksiyon | Açıklama |
|------------|----------|
| `cihazlar` | Kayıtlı cihaz bilgileri |
| `kullanicilar` | Kullanıcı hesapları |
| `onay_istekleri` | Durum değişikliği onay istekleri |
| `kullanici_yetkileri` | Kullanıcı yetkilendirmeleri |
| `durum_onaylayicilari` | Durum onaylama yetkileri |

## 🔄 Senkronizasyon Nasıl Çalışır?

- **Cihaz Ekleme:** Bir telefonda eklenen cihaz anında diğer telefonlara yansır
- **Durum Güncelleme:** Cihaz durumu değiştiğinde tüm kullanıcılar görür
- **Kullanıcı Yönetimi:** Kullanıcılar bulutta saklanır, herhangi bir cihazdan giriş yapılabilir
- **Onay İstekleri:** Onay talepleri tüm yetkili kullanıcılara görünür

## 🚀 APK Derleme

Firebase kurulumu tamamlandıktan sonra:

```bash
cd servobiz
flutter clean
flutter pub get
flutter build apk --release
```

APK dosyası: `build/app/outputs/flutter-apk/app-release.apk`

## ⚠️ Önemli Notlar

1. **google-services.json** dosyası olmadan uygulama çalışmaz
2. İlk çalıştırmada internet bağlantısı gereklidir
3. Firestore'da "Test modunda" başlatırsanız 30 gün sonra güvenlik kurallarını güncellemeniz gerekir
4. Her telefonun internete bağlı olması gerekir senkronizasyon için

## 📞 Destek

Sorun yaşarsanız Firebase belgelerine bakın:
- [Firebase Flutter Kurulumu](https://firebase.google.com/docs/flutter/setup)
- [Cloud Firestore Flutter](https://firebase.google.com/docs/firestore/quickstart#flutter)
