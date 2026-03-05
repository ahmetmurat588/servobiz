# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore
-keep class com.google.cloud.firestore.** { *; }
-keep class io.grpc.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# R8 uyumluluk
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# gRPC / OkHttp (Firestore bağımlılığı)
-dontwarn com.squareup.okhttp.**
-dontwarn io.grpc.okhttp.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
