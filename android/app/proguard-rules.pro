# ONNX Runtime - its native code looks up these Java classes/methods by name via
# JNI (GetMethodID). R8 must not rename or strip them, or OrtSession.run aborts
# with "JNI DETECTED ERROR ... java_class == null".
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# ObjectBox - uses generated code + reflection over @Entity classes.
-keep class io.objectbox.** { *; }
-dontwarn io.objectbox.**
-keep @io.objectbox.annotation.Entity class * { *; }
