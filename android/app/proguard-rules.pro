# Crux — R8 / ProGuard keep rules for release builds.
#
# Flutter itself needs almost nothing kept (Dart is AOT-compiled), but a few
# plugins reach Java/Kotlin classes reflectively and get stripped otherwise.
# Symptom of a missing rule is always the same: works in debug, crashes or
# silently no-ops in release.

# ---------------------------------------------------------------------------
# Flutter engine / embedding
# ---------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# flutter_local_notifications — schedules are restored from serialized JSON
# via Gson; obfuscating those model classes breaks reminders after reboot.
# ---------------------------------------------------------------------------
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Gson (bundled by the notifications plugin) uses generic type tokens.
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ---------------------------------------------------------------------------
# audioplayers (rest-timer tone) — ExoPlayer/Media3 reflection
# ---------------------------------------------------------------------------
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ---------------------------------------------------------------------------
# Networking (Supabase / OkHttp / Conscrypt) used by the cloud sync + coach
# ---------------------------------------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ---------------------------------------------------------------------------
# image_picker / androidx lifecycle callbacks resolved by name
# ---------------------------------------------------------------------------
-keep class androidx.lifecycle.DefaultLifecycleObserver
-keep class androidx.core.app.CoreComponentFactory { *; }

# ---------------------------------------------------------------------------
# Keep the stack traces useful after obfuscation. Upload the mapping file
# (build/app/outputs/mapping/release/mapping.txt) to Play so crash reports
# de-obfuscate — Play prompts for this after each upload.
# ---------------------------------------------------------------------------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
