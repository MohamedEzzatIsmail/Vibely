# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Supabase / Realtime / GoTrue
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# media_kit
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }
-dontwarn com.alexmercerind.**

# Gson / JSON (used by several plugins)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep serializable model classes
-keep class * extends java.io.Serializable { *; }

# Dart/Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
