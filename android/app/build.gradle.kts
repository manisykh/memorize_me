import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
val shouldConfigureReleaseSigning = hasReleaseKeystore && isReleaseBuildRequested

if (shouldConfigureReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun releaseKeystoreProperty(name: String): String {
    val value = keystoreProperties[name]?.toString()?.trim()
    require(!value.isNullOrEmpty()) {
        "Missing '$name' in android/key.properties. Run android/setup_release_signing.ps1 or copy android/key.properties.example."
    }
    return value
}

android {
    namespace = "com.memorize.me"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.memorize.me"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (shouldConfigureReleaseSigning) {
            create("release") {
                keyAlias = releaseKeystoreProperty("keyAlias")
                keyPassword = releaseKeystoreProperty("keyPassword")
                val releaseStoreFile = file(releaseKeystoreProperty("storeFile"))
                require(releaseStoreFile.exists()) {
                    "Release keystore file not found: ${releaseStoreFile.absolutePath}"
                }
                storeFile = releaseStoreFile
                storePassword = releaseKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (shouldConfigureReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (isReleaseBuildRequested) {
                throw GradleException(
                    "Missing android/key.properties. Run android/setup_release_signing.ps1 or copy android/key.properties.example."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
