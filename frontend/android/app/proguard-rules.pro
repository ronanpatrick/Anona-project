# flutter_local_notifications uses GSON internally to serialize/deserialize
# scheduled notifications. R8's full-mode shrinking strips the generic type
# signatures that GSON relies on, causing the "Missing type parameter" crash
# at runtime. These rules preserve the required type information.

# Retain generic signatures of TypeToken and all its subclasses.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Keep XML pull parser classes used by the notifications library.
-keep class org.xmlpull.** { *; }
