# R8 rules for the release build.
#
# Only classes reached from native code need listing here. Everything the Dart
# side touches goes through the Flutter engine's own plugin registry, which
# ships its own rules, and anything reached by ordinary Java calls R8 can see
# for itself.

# ONNX Runtime. The JNI layer looks these up by name from C++, so R8 cannot see
# the references and would otherwise strip or rename them. Symptom if this is
# missing: the models load in debug and throw NoSuchMethodError in release.
-keep class ai.onnxruntime.** { *; }
-keepclasseswithmembernames class ai.onnxruntime.** {
    native <methods>;
}
-dontwarn ai.onnxruntime.**

# Our own JNI-adjacent vision classes are instantiated from the platform
# channel by name.
-keep class ai.arcvanta.arcvanta.vision.** { *; }

# Line numbers in release crash reports. Without this a stack trace from the
# field is a list of addresses.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
