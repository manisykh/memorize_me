# Flutter plugins publish the consumer rules they require. Keep this project
# file intentionally small so R8 can still remove unused Android resources.
#
# Preserve generic signatures and annotations used by Firebase/Google SDKs and
# by reflection-based serializers bundled by dependencies.
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,AnnotationDefault

# Keep Flutter plugin entry points that may be registered through generated
# Android embedding code.
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
