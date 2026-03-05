import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Firebase için
}

// Keystore properties (opsiyonel - imzalama için)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.servobiz"
    
    // ===== API 26-29 OPTİMİZASYONU =====
    compileSdk = 36  // Eklentilerin gerektirdiği minimum SDK
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // Eski Android'lerde yeni Java özellikleri
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            // Manifest birleştirme optimizasyonu
            manifest.srcFile("src/main/AndroidManifest.xml")
        }
    }

    defaultConfig {
        applicationId = "com.example.servobiz"
        
        // ===== API 26-34 HEDEFLEME =====
        minSdk = 26  // Android 8.0 (API 26) - Samsung S9+
        targetSdk = 34  // Android 14 (API 34) - Güncel hedef
        
        versionCode = 1
        versionName = "1.0.0"
        
        // ===== PERFORMANS OPTİMİZASYONU =====
        multiDexEnabled = true
        multiDexKeepProguard = file("multidex-config.pro")
        
        // Dosya export için gerekli
        vectorDrawables.useSupportLibrary = true
    }

    // ===== İMZALAMA KONFİGÜRASYONU (Release için) =====
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // ===== APK OPTİMİZASYONU =====
    buildTypes {
        release {
            // Hızlı çalışma için maksimum optimizasyon
            isMinifyEnabled = true  // Kod küçültme (R8)
            isShrinkResources = true  // Kaynak küçültme
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Debug sembollerini ayır (APK küçültme)
            ndk {
                debugSymbolLevel = "FULL"  // Hata raporlama için
            }
            
            // İmzalama
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        
        debug {
            isDebuggable = true
            isMinifyEnabled = false
        }
    }
    
    // ===== CPU MİMARİ DESTEĞİ =====
    // Universal APK - tüm cihazlarda çalışır
    // (Samsung S9, S22 Ultra, Redmi Note 9 vb.)
    
    // ===== PAKETLEME OPTİMİZASYONU =====
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/license.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/notice.txt"
            excludes += "META-INF/ASL2.0"
            excludes += "META-INF/*.kotlin_module"
        }
    }
    
    // ===== DERLEME OPTİMİZASYONU =====
    buildFeatures {
        buildConfig = true
    }
    
    // ===== LINT OPTİMİZASYONU =====
    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable.addAll(listOf("InvalidPackage", "MissingTranslation"))
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ===== JAVA 8+ DESTEĞİ (Eski Android'ler için) =====
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ===== MULTIDEX (Büyük uygulamalar için) =====
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ===== ANDROİX KÜTÜPHANELERİ (Hızlı çalışma için) =====
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    
    // ===== ARKA PLAN SERVİSLERİ İÇİN (WorkManager) =====
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // ===== BİLDİRİMLER İÇİN =====
    implementation("androidx.core:core:1.12.0")
    
    // ===== FIREBASE (Pubspec'daki versiyonlarla uyumlu) =====
    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-firestore")
    
    // ===== PERMISSION HANDLER =====
    implementation("androidx.activity:activity-ktx:1.8.2")
    implementation("androidx.fragment:fragment-ktx:1.6.2")
}