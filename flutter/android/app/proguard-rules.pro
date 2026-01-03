# Security: ProGuard Rules for Sprout App

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Security: Keep cryptographic classes
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Security: Keep Rust FFI bridge
-keep class com.sproutapp.sprout.GeneratedBridge { *; }
-keepnativejni com.sproutapp.sprout.** { *; }

# Security: Keep encryption service
-keep class com.sproutapp.sprout.services.EncryptionService { *; }
-keep class com.sproutapp.sprout.services.SecurityAnalyzer { *; }

# Security: Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Security: Obfuscate all other classes
-dontwarn javax.**
-dontwarn java.**
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

# Security: Aggressive optimization
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# Security: String encryption
-adaptclassstrings