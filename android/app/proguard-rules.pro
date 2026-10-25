# Release builds are shrunk with R8, which strips classes ML Kit loads by
# reflection and makes translation model downloads fail.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.datatransport.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
