-keeppackagenames **
-keep class skip.** { *; }
-keep class tools.skip.** { *; }
-keep class kotlin.jvm.functions.** {*;}
-keep class com.sun.jna.** { *; }
-dontwarn java.awt.**
-keep class * implements com.sun.jna.** { *; }
-keep class * implements skip.bridge.** { *; }
-keep class **._ModuleBundleAccessor_* { *; }
-keep class ecash.wallet.mobile.** { *; }
# The Skip bridge resolves its transpiled Kotlin peer classes BY NAME via JNI (FindClass), so R8
# must not rename/remove them. `ecash.wallet.mobile.**` (the Fuse app module) was kept; the separate
# Lite `WalletService` package (`wallet.service.**`) was NOT — its omission crashed Create-wallet in
# release with `ClassNotFoundException: wallet.service.NetworkRegistry` (NetworkRegistry_Bridge.swift).
-keep class wallet.service.** { *; }
# BDK + secp256k1 are JNI/UniFFI native bindings loaded reflectively — keep them intact in release.
-keep class org.bitcoindevkit.** { *; }
-keep class fr.acinq.secp256k1.** { *; }
