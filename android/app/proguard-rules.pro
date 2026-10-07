# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# ML Kit
-keep class com.google.mlkit.** { *; }

# Keep all models
-keep class com.example.study_library.** { *; }
-keep class com.studylibrary.study_library.** { *; }
-keep class com.studylibrary.app.** { *; }

# Play Core & Split Install
-dontwarn com.google.android.play.core.**

# ML Kit Text Recognition languages not bundled
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.**
