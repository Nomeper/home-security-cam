# Agora RTC uses JNI and callbacks that must remain discoverable after R8.
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Keep the Android foreground-service plugin entry points.
-keep class com.pravera.flutter_foreground_task.** { *; }
